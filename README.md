This repository provides local Podman orchestration and browser-based smoke tests for LibreTexts ADAPT development work.

# ADAPT Test Suite

The test suite is intentionally separate from the upstream ADAPT contribution. Local credentials,
container state, Playwright artifacts, and screenshots remain here.

## Screenshots

<!-- screenshots:begin (managed by screenshot-docs) -->
![Default assignment mode with per-question responses selected](docs/screenshots/assignment_mode_default.png)
![Multiple responses showing the per-response penalty](docs/screenshots/assignment_mode_multiple_responses.png)
![Whole-assignment mode with compact controls](docs/screenshots/assignment_mode_mastery.png)
![New-assignment state requiring questions before random selection](docs/screenshots/dynamic_questioning_new_assignment.png)
![Dynamic questioning controls showing fixed-seed and random-seed variation](docs/screenshots/dynamic_questioning_mastery.png)
![Completed mastery attempt in the student assignment view](docs/screenshots/student_mastery_completed_attempt_context.png)
![Native questions using the per-question attempt policy](docs/screenshots/student_native_per_question_policy.png)
![Native whole-assignment attempt with the persistent completion panel](docs/screenshots/student_native_whole_assignment_completed.png)
![Fresh whole-assignment attempt in the student assignment view](docs/screenshots/student_mastery_new_attempt_context.png)
<!-- screenshots:end -->

## Run ADAPT from the mastery worktree

Copy and edit the local account configuration once:

```bash
cp podman-local.example.yml podman-local.yml
chmod 600 podman-local.yml
```

Startup, reset, account, and fixture commands fail before invoking Podman when this file is missing
or unreadable. Read-only and cleanup commands remain available without it.

Start the Podman environment from the sibling `LibreTexts-ADAPT` repository's
`mastery-retakes` branch:

```bash
./run_podman-worktree.sh
```

Rebuild the worktree image and relaunch the environment after source changes:

```bash
./run_podman-worktree.sh rebuild
```

The launcher automatically uses the branch's registered worktree when one exists, preserving
uncommitted changes. Otherwise, it builds the local or `origin/mastery-retakes` ref from the
regular ADAPT checkout. Set `ADAPT_REPOSITORY_DIR` only when that checkout is not in the default
sibling location, or set `ADAPT_WORKTREE_DIR` to override worktree discovery.

For future work, set one variable to select another branch and its worktree. The launcher derives
its image, container, network, and volume names from the same value:

```bash
ADAPT_WORKTREE_BRANCH=feature/example ./run_podman-worktree.sh
```

## Run the visual smoke test

Install the browser-test dependencies once:

```bash
npm install
npx playwright install chromium
```

With ADAPT running at `http://localhost:8081`, run:

```bash
./run_playwright_tests.sh
```

The test logs in with the instructor account from `podman-local.yml`, opens the unsaved New
Assignment form, checks the assignment-mode and dynamic-questioning controls, and refreshes the committed captures under
`docs/screenshots/`. It does not save an assignment or modify the ADAPT source tree. Failure traces
and incidental failure screenshots remain ignored under `test-results/`.
