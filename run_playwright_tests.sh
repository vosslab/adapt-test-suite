#!/usr/bin/env bash
# run_playwright_tests.sh - run the ADAPT Playwright browser tests.

set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Usage: run_playwright_tests.sh [-h|--help] [PLAYWRIGHT_ARGS...]

  -h, --help    Print this help and exit 0.

All remaining arguments are forwarded to Playwright.
USAGE
}

PLAYWRIGHT_ARGS=()
while (($# > 0)); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            PLAYWRIGHT_ARGS+=("$1")
            shift
            ;;
    esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly REPO_ROOT

cd "$REPO_ROOT"

if ! command -v node >/dev/null 2>&1; then
    printf 'error: node is not installed or not on PATH\n' >&2
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    printf 'error: npm is not installed or not on PATH\n' >&2
    exit 1
fi

if [[ ! -d node_modules ]]; then
    printf 'error: node_modules is missing; run npm install first\n' >&2
    exit 1
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
    printf 'error: Playwright is not installed; run npm install first\n' >&2
    exit 1
fi

if [[ ! -f tests/playwright/playwright.config.mjs ]]; then
    printf 'error: tests/playwright/playwright.config.mjs is missing\n' >&2
    exit 1
fi

"$REPO_ROOT/run_podman-worktree.sh" setup-fixtures

printf '==> Playwright test'
if ((${#PLAYWRIGHT_ARGS[@]} > 0)); then
    printf ' %s' "${PLAYWRIGHT_ARGS[@]}"
fi
printf '\n'

PLAYWRIGHT_EXIT=0
set +e
node_modules/.bin/playwright test \
    --config tests/playwright/playwright.config.mjs \
    ${PLAYWRIGHT_ARGS[@]+"${PLAYWRIGHT_ARGS[@]}"}
PLAYWRIGHT_EXIT=$?
set -e

if ((PLAYWRIGHT_EXIT == 0)); then
    printf 'PASS: Playwright tests passed.\n'
else
    printf 'FAIL: Playwright tests failed (exit code %s).\n' "$PLAYWRIGHT_EXIT" >&2
fi

exit "$PLAYWRIGHT_EXIT"
