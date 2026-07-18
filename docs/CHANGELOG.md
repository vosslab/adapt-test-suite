## 2026-07-18

### Additions and New Features

- Added an authoritative implementation outcome to `the_plan.md` while preserving the original
  proposal as historical context.
- Added `docs/ADAPT_MAINTAINER_STYLE.md` with concise, evidence-based conventions observed in the
  upstream Laravel, Vue, migration, and Feature-test code.
- Added deterministic Native-question assignments for comparing per-question and whole-assignment
  attempt policies with an enrolled local student.
- Added Playwright coverage and screenshots for completing, reviewing, and restarting a
  whole-assignment attempt while preserving the legacy per-question workflow.

### Fixes and Maintenance

- Made the mastery Podman launcher automatically fall back to the requested branch in the regular
  ADAPT checkout when no separate worktree is registered.
- Derived all worktree-specific Podman resource names from `ADAPT_WORKTREE_BRANCH` so one variable
  selects future branches and worktrees.
- Made both Podman entry points fail before container work when account-dependent commands cannot
  read `podman-local.yml`, while preserving configuration-free help, build, inspection, and cleanup.
- Clarified the Podman command lifecycle: `up` and `rebuild` preserve data, `reset` recreates the
  database and fixtures, and `clean` removes the complete local environment.
- Updated browser coverage for the persistent attempt-completion panel and numbered
  `Start Attempt` action that replaced the second completion popup.

### Developer Tests and Notes

- Verified the worktree production build and all four Playwright tests against the local Podman
  environment.

## 2026-07-16

### Additions and New Features

- Added a Playwright visual smoke test for ADAPT assignment-mode and algorithmic-variation controls.
- Added reproducible local Playwright setup and committed assignment-properties screenshots for
  per-question, multiple-response, whole-assignment, new-assignment, and algorithmic states.
- Added `run_playwright_tests.sh` as the visible browser-test entry point.
- Added runner help, dependency preflights, argument forwarding, and explicit PASS/FAIL reporting.
- Added a first-class `run_podman-worktree.sh rebuild` command for rebuilding and relaunching
  the current ADAPT worktree without an environment-variable prefix.
- Added a focused student Playwright capture of the completed-attempt feedback-retention notice
  and the fresh in-progress attempt that follows it.

### Fixes and Maintenance

- Assigned a deterministic local central identity to the student fixture so an in-progress
  mastery attempt exercises ADAPT's normal submission-policy check and renders as open.
- Adapted the Podman launchers to run from this test repository against a sibling ADAPT checkout.
- Replaced Ruby YAML parsing with Python 3 and stopped copying a temporary launcher into worktrees.
- Made the Podman launcher load the repository's documented Python environment before using PyYAML.
- Clarified that Playwright users should prefer repository runners, that documentation captures
  default to `docs/screenshots/`, and that repositories own their build and server conventions.

### Developer Tests and Notes

- Verified that `run_podman-worktree.sh status` finds the running mastery Podman environment.
