import { mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

import { expect, test } from '@playwright/test';
import YAML from 'yaml';
import { REPO_ROOT } from './repo_root.mjs';

const localConfig = YAML.parse(readFileSync(path.join(REPO_ROOT, 'podman-local.yml'), 'utf8'));
const screenshotsDir = path.join(REPO_ROOT, 'docs', 'screenshots');
const testCourseId = process.env.ADAPT_TEST_COURSE_ID;

mkdirSync(screenshotsDir, { recursive: true });

async function loginAsInstructor(page) {
  await page.goto('/login');
  await page.locator('#email').fill(localConfig.instructor.email);
  await page.locator('#password').fill(localConfig.instructor.password);
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await expect(page).toHaveURL(/\/home$/);
}

async function waitForRadioTransitions(radioGroup) {
  await radioGroup.evaluate(async (element) => {
    const animations = element.getAnimations({ subtree: true });
    await Promise.all(animations.map((animation) => animation.finished));
  });
}

test('captures the assignment mode and algorithmic variation controls', async ({ page }) => {
  await loginAsInstructor(page);
  expect(testCourseId).toMatch(/^\d+$/);
  await page.goto('/instructors/courses');
  await page.getByRole('link', { name: 'ADAPT Mastery Browser Tests', exact: true }).click();
  await expect(page).toHaveURL(`/instructors/courses/${testCourseId}/assignments`);
  await page.getByRole('button', { name: 'New Assignment', exact: true }).click();

  const modal = page.locator('#modal-assignment-properties');
  await expect(modal).toBeVisible();

  const assignmentModeCard = page.getByRole('heading', {
    name: 'Assignment Mode',
    exact: true
  }).locator('xpath=../..');
  const dynamicQuestioningCard = page.getByRole('heading', {
    name: 'Dynamic Questioning',
    exact: true
  }).locator('xpath=../..');
  const dynamicQuestioningHeader = dynamicQuestioningCard.locator('.card-header');

  const attemptStructure = page.locator('#mastery_retake_enabled');
  const responsesPerQuestion = page.getByLabel('Responses allowed per question');
  const assignmentAttempts = page.getByLabel('Whole-assignment attempts allowed');

  await expect(attemptStructure).toBeVisible();
  await expect(responsesPerQuestion).toBeVisible();
  await assignmentModeCard.screenshot({
    path: path.join(screenshotsDir, 'assignment_mode_default.png')
  });

  await responsesPerQuestion.fill('2');
  await expect(page.locator('#number_of_allowed_attempts_penalty')).toBeVisible();
  await assignmentModeCard.screenshot({
    path: path.join(screenshotsDir, 'assignment_mode_multiple_responses.png')
  });

  const randomSubset = page.locator('#randomizations input[value="1"]');
  await expect(randomSubset).toBeDisabled();
  await expect(page.locator('#number_of_randomized_assessments')).toBeHidden();
  await dynamicQuestioningCard.screenshot({
    path: path.join(screenshotsDir, 'dynamic_questioning_new_assignment.png')
  });

  const wholeAssignment = page.locator('#mastery_retake_enabled input[value="1"]');
  const perQuestion = page.locator('#mastery_retake_enabled input[value="0"]');
  await wholeAssignment.locator('xpath=following-sibling::label').click();
  await expect(wholeAssignment).toBeChecked();
  await expect(perQuestion).not.toBeChecked();
  await waitForRadioTransitions(attemptStructure);
  await wholeAssignment.evaluate((element) => element.blur());
  await expect(responsesPerQuestion).toBeHidden();
  await expect(assignmentAttempts).toBeVisible();
  await assignmentModeCard.screenshot({
    path: path.join(screenshotsDir, 'assignment_mode_mastery.png')
  });
  await dynamicQuestioningCard.screenshot({
    path: path.join(screenshotsDir, 'dynamic_questioning_mastery.png')
  });

  await page.locator('#attempt-structure-tooltip').hover();
  await expect(page.locator('.tooltip.show')).toBeVisible();

  await expect(page.locator('#randomizations')).toBeVisible();
  await expect(page.locator('#algorithmic')).toBeVisible();

  await page.locator('#every-assigned-question-tooltip').hover();
  await expect(page.locator('.tooltip.show')).toBeVisible();
  await dynamicQuestioningHeader.hover();
  await expect(page.locator('.tooltip.show')).toBeHidden();
  await page.locator('#random-subset-question-tooltip').hover();
  await expect(page.locator('.tooltip.show')).toBeVisible();
  await dynamicQuestioningHeader.hover();
  await expect(page.locator('.tooltip.show')).toBeHidden();
});

test('configures a random subset for an existing two-question assignment', async ({ page }) => {
  await loginAsInstructor(page);
  expect(testCourseId).toMatch(/^\d+$/);
  await page.goto('/instructors/courses');
  await page.getByRole('link', { name: 'ADAPT Mastery Browser Tests', exact: true }).click();
  await expect(page).toHaveURL(`/instructors/courses/${testCourseId}/assignments`);
  await page.getByRole('link', {
    name: 'Assignment properties for Native Questions: Per-Question Attempts',
    exact: true
  }).click();

  const modal = page.locator('#modal-assignment-properties');
  await expect(modal).toBeVisible();

  const randomSubset = modal.locator('#randomizations input[value="1"]');
  const questionsPerStudent = modal.locator('#number_of_randomized_assessments');
  await expect(randomSubset).toBeEnabled();
  await expect(questionsPerStudent).toBeHidden();

  await randomSubset.locator('xpath=following-sibling::label').click();

  await expect(randomSubset).toBeChecked();
  await expect(questionsPerStudent).toBeVisible();
  await expect(questionsPerStudent).toHaveValue('1');
  await expect(modal.getByText('of 2 assignment questions.', { exact: true })).toBeVisible();
});
