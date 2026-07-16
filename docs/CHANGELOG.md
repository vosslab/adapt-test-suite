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
