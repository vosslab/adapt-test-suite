#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

WORKTREE_BRANCH="${ADAPT_WORKTREE_BRANCH:-mastery-retakes}"
WORKTREE_DIR="${ADAPT_WORKTREE_DIR:-}"

if [[ -z "$WORKTREE_DIR" ]]; then
    WORKTREE_DIR="$(git -C "$SCRIPT_DIR" worktree list --porcelain | awk \
        -v branch="refs/heads/$WORKTREE_BRANCH" '
            /^worktree / { path = substr($0, 10) }
            $0 == "branch " branch { print path; exit }
        ')"
fi

if [[ -z "$WORKTREE_DIR" || ! -d "$WORKTREE_DIR" ]]; then
    printf 'error: worktree for branch %s was not found\n' "$WORKTREE_BRANCH" >&2
    printf 'Set ADAPT_WORKTREE_DIR to the worktree path and try again.\n' >&2
    exit 1
fi

if [[ ! -x "$SCRIPT_DIR/run_podman.sh" ]]; then
    printf 'error: %s is missing or is not executable\n' "$SCRIPT_DIR/run_podman.sh" >&2
    exit 1
fi

INNER_SCRIPT="$WORKTREE_DIR/.run_podman-worktree-inner.sh"
cleanup() {
    rm -f "$INNER_SCRIPT"
}
trap cleanup EXIT

# run_podman.sh intentionally uses its own location as the source directory.
# Execute a temporary copy from inside the linked worktree so WORKTREE means
# the mastery implementation rather than this checkout.
cp "$SCRIPT_DIR/run_podman.sh" "$INNER_SCRIPT"
chmod +x "$INNER_SCRIPT"

export ADAPT_REF=WORKTREE
export ADAPT_IMAGE="${ADAPT_IMAGE:-localhost/libretexts-adapt:mastery-worktree}"
export ADAPT_PORT="${ADAPT_PORT:-8081}"
export ADAPT_NETWORK="${ADAPT_NETWORK:-adapt-mastery-local}"
export ADAPT_APP_CONTAINER="${ADAPT_APP_CONTAINER:-adapt-mastery-app}"
export ADAPT_DB_CONTAINER="${ADAPT_DB_CONTAINER:-adapt-mastery-mysql}"
export ADAPT_REDIS_CONTAINER="${ADAPT_REDIS_CONTAINER:-adapt-mastery-redis}"
export ADAPT_DB_VOLUME="${ADAPT_DB_VOLUME:-adapt-mastery-mysql-data}"
export ADAPT_LOCAL_CONFIG="${ADAPT_LOCAL_CONFIG:-$SCRIPT_DIR/podman-local.yml}"
export ADAPT_COMMAND_NAME="$SCRIPT_DIR/run_podman-worktree.sh"

printf 'Using worktree: %s (%s)\n' "$WORKTREE_DIR" "$WORKTREE_BRANCH"
printf 'Using URL: http://localhost:%s\n' "$ADAPT_PORT"

if (($# == 0)); then
    set -- up
fi

"$INNER_SCRIPT" "$@"
