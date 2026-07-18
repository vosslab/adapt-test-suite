import { mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

import { expect, test } from '@playwright/test';
import YAML from 'yaml';
import { REPO_ROOT } from './repo_root.mjs';

const localConfig = YAML.parse(readFileSync(path.join(REPO_ROOT, 'podman-local.yml'), 'utf8'));
const screenshotsDir = path.join(REPO_ROOT, 'docs', 'screenshots');

mkdirSync(screenshotsDir, { recursive: true });

async function loginAsStudent(page) {
  await page.goto('/login');
  await page.locator('#email').fill(localConfig.student.email);
  await page.locator('#password').fill(localConfig.student.password);
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await expect(page).toHaveURL(/\/students\/courses$/);
  await expect(page.getByRole('heading', { name: 'My Courses', exact: true })).toBeVisible();
}

async function openStudentAssignment(page, assignmentName) {
  await page.getByRole('link', { name: /ADAPT Mastery Browser Tests/ }).click();
  await expect(page).toHaveURL(/\/students\/courses\/\d+\/assignments$/);
  await page.getByRole('link', { name: assignmentName, exact: true }).click();
  await page.getByRole('button', { name: 'View Assessments', exact: true }).click();
}

async function closeSubmissionSummary(page) {
  const submissionModal = page.locator('#modal-submission-accepted');
  await expect(submissionModal).toBeVisible();
  await submissionModal.getByRole('button', { name: 'Close' }).click();
  await expect(submissionModal).toBeHidden();
}

test('an enrolled student starts a fresh whole-assignment attempt', async ({ page }) => {
  test.setTimeout(60_000);
  await loginAsStudent(page);

  await openStudentAssignment(page, 'WeBWorK Test: Whole-Assignment Attempts');

  const completedBadge = page.getByText(/Assignment attempt 1.*Completed/, { exact: false });
  await expect(completedBadge).toBeVisible();
  await expect(page.getByText('Status: Closed', { exact: true })).toBeVisible();
  const startNewAttempt = page.getByRole('button', { name: 'Start Attempt 2', exact: true });
  await expect(startNewAttempt).toBeVisible();
  await expect(page.getByText('Practice every question again. Your highest score stays the same.', { exact: true })).toBeVisible();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_mastery_completed_attempt_context.png'),
    clip: { x: 0, y: 0, width: 1280, height: 330 }
  });

  await startNewAttempt.click();

  const activeBadge = page.getByText(/Assignment attempt 2.*In progress/, { exact: false });
  await expect(activeBadge).toBeVisible();
  await expect(page.locator('.vld-overlay')).toBeHidden({ timeout: 30_000 });
  await page.waitForTimeout(500);
  await expect(page.getByText('Status: Open', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: /Start Attempt/ })).toBeHidden();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_mastery_new_attempt_context.png'),
    clip: { x: 0, y: 0, width: 1280, height: 330 }
  });
});

test('native per-question attempts retain correct questions', async ({ page }) => {
  test.setTimeout(60_000);
  await loginAsStudent(page);
  await openStudentAssignment(page, 'Native Questions: Per-Question Attempts');

  await expect(page.getByText(/Assignment attempt/, { exact: false })).toBeHidden();
  await page.getByText('Blue', { exact: true }).click();
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await closeSubmissionSummary(page);
  await expect(page.getByText('5/5 points', { exact: true })).toBeVisible();

  await page.getByRole('menuitemradio', { name: 'Go to page 2' }).click();
  await page.getByText('5', { exact: true }).click();
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await closeSubmissionSummary(page);
  await expect(page.getByText('Status: Open', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Submit', exact: true })).toBeEnabled();
  const completedModal = page.locator('#modal-assignment-completed');
  await expect(completedModal).toBeVisible();
  await completedModal.getByRole('button', { name: 'Close' }).click();
  await expect(completedModal).toBeHidden();

  await page.getByRole('menuitemradio', { name: 'Go to page 1' }).click();
  await expect(page.getByText('5/5 points', { exact: true })).toBeVisible();
  await expect(page.getByRole('radio', { name: /Blue/ })).toBeChecked();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_native_per_question_policy.png')
  });
});

test('an enrolled student completes a native whole-assignment attempt', async ({ page }) => {
  test.setTimeout(60_000);
  await loginAsStudent(page);
  await openStudentAssignment(page, 'Native Questions: Whole-Assignment Attempts');

  await expect(page.getByText(/Assignment attempt 1.*In progress/, { exact: false })).toBeVisible();
  await expect(page.getByText('Which color is a primary color?', { exact: true })).toBeVisible();
  await page.getByText('Blue', { exact: true }).click();
  await expect(page.getByRole('radio', { name: 'Blue' })).toBeChecked();
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await closeSubmissionSummary(page);

  await page.getByRole('menuitemradio', { name: 'Go to page 2' }).click();
  await expect(page.getByText('Which number is even?', { exact: true })).toBeVisible();
  await page.getByText('4', { exact: true }).click();
  await expect(page.getByRole('radio', { name: '4' })).toBeChecked();
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await closeSubmissionSummary(page);

  await expect(page.locator('#modal-assignment-completed')).toBeHidden();
  await expect(page.getByText('Assignment mastered in attempt 1.', { exact: true })).toBeVisible();
  await expect(page.getByText('Practice every question again. Your highest score stays the same.', { exact: true })).toBeVisible();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_native_whole_assignment_completed.png')
  });
  await page.getByRole('button', { name: 'Start Attempt 2', exact: true }).click();
  await expect(page.getByText(/Assignment attempt 2.*In progress/, { exact: false })).toBeVisible();
  await expect(page.getByText('Which color is a primary color?', { exact: true })).toBeVisible();
  await expect(page.getByRole('radio', { name: 'Blue' })).not.toBeChecked();
  await expect(page.getByRole('button', { name: 'Submit', exact: true })).toBeEnabled();
});
