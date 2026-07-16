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

test('an enrolled student starts a fresh whole-assignment attempt', async ({ page }) => {
  test.setTimeout(60_000);
  await loginAsStudent(page);

  await page.getByRole('link', { name: /ADAPT Mastery Browser Tests/ }).click();
  await expect(page).toHaveURL(/\/students\/courses\/\d+\/assignments$/);
  await page.getByRole('link', { name: 'Whole-Assignment Mastery Retake', exact: true }).click();
  await page.getByRole('button', { name: 'View Assessments', exact: true }).click();

  const completedBadge = page.getByText(/Mastery attempt 1.*Completed/, { exact: false });
  await expect(completedBadge).toBeVisible();
  await expect(page.getByText('Status: Closed', { exact: true })).toBeVisible();
  const startNewAttempt = completedBadge.locator('xpath=following-sibling::button');
  await expect(startNewAttempt).toBeVisible();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_mastery_completed_attempt_context.png'),
    clip: { x: 0, y: 0, width: 1280, height: 330 }
  });

  await page.locator('#app').evaluate((app) => {
    app.__vue__.$root.$emit('bv::show::modal', 'modal-assignment-completed');
  });
  const completedModal = page.locator('#modal-assignment-completed');
  await expect(completedModal).toContainText('Your responses and feedback remain available when you leave and return.');
  await page.waitForTimeout(500);
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_mastery_completion_modal_context.png')
  });
  await completedModal.locator('.modal-dialog').screenshot({
    path: path.join(screenshotsDir, 'student_mastery_completion_modal.png')
  });
  await page.locator('#app').evaluate((app) => {
    app.__vue__.$root.$emit('bv::hide::modal', 'modal-assignment-completed');
  });
  await expect(completedModal).toBeHidden();

  await startNewAttempt.click();

  const activeBadge = page.getByText(/Mastery attempt 2.*In progress/, { exact: false });
  await expect(activeBadge).toBeVisible();
  await expect(page.locator('.vld-overlay')).toBeHidden({ timeout: 30_000 });
  await page.waitForTimeout(500);
  await expect(page.getByText('Status: Open', { exact: true })).toBeVisible();
  await expect(activeBadge.locator('xpath=following-sibling::button')).toBeHidden();
  await page.screenshot({
    path: path.join(screenshotsDir, 'student_mastery_new_attempt_context.png'),
    clip: { x: 0, y: 0, width: 1280, height: 330 }
  });
});
