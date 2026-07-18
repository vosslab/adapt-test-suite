#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly REPO_ROOT

ADAPT_REPOSITORY_DIR="${ADAPT_REPOSITORY_DIR:-$REPO_ROOT/../libretexts-adapt}"
WORKTREE_BRANCH="${ADAPT_WORKTREE_BRANCH:-mastery-retakes}"
WORKTREE_SLUG="${WORKTREE_BRANCH//\//-}"
WORKTREE_DIR="${ADAPT_WORKTREE_DIR:-}"
ADAPT_SOURCE_REF=""
SOURCE_DESCRIPTION=""

if ! git -C "$ADAPT_REPOSITORY_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'error: ADAPT repository was not found: %s\n' "$ADAPT_REPOSITORY_DIR" >&2
    printf 'Set ADAPT_REPOSITORY_DIR to the ADAPT checkout and try again.\n' >&2
    exit 1
fi

if [[ -z "$WORKTREE_DIR" ]]; then
    WORKTREE_DIR="$(git -C "$ADAPT_REPOSITORY_DIR" worktree list --porcelain | awk \
        -v branch="refs/heads/$WORKTREE_BRANCH" '
            /^worktree / { path = substr($0, 10) }
            $0 == "branch " branch { print path; exit }
        ')"
fi

if [[ -n "$WORKTREE_DIR" ]]; then
    if [[ ! -d "$WORKTREE_DIR" ]]; then
        printf 'error: ADAPT worktree directory was not found: %s\n' "$WORKTREE_DIR" >&2
        printf 'Correct ADAPT_WORKTREE_DIR or unset it to enable automatic discovery.\n' >&2
        exit 1
    fi
    ADAPT_SOURCE_DIR="$WORKTREE_DIR"
    ADAPT_SOURCE_REF="WORKTREE"
    SOURCE_DESCRIPTION="worktree: $WORKTREE_DIR ($WORKTREE_BRANCH)"
elif git -C "$ADAPT_REPOSITORY_DIR" show-ref --verify --quiet \
    "refs/heads/$WORKTREE_BRANCH"; then
    ADAPT_SOURCE_DIR="$ADAPT_REPOSITORY_DIR"
    ADAPT_SOURCE_REF="$WORKTREE_BRANCH"
    SOURCE_DESCRIPTION="branch: $WORKTREE_BRANCH from $ADAPT_REPOSITORY_DIR"
elif git -C "$ADAPT_REPOSITORY_DIR" show-ref --verify --quiet \
    "refs/remotes/origin/$WORKTREE_BRANCH"; then
    ADAPT_SOURCE_DIR="$ADAPT_REPOSITORY_DIR"
    ADAPT_SOURCE_REF="origin/$WORKTREE_BRANCH"
    SOURCE_DESCRIPTION="branch: origin/$WORKTREE_BRANCH from $ADAPT_REPOSITORY_DIR"
else
    printf 'error: branch %s is not available in %s\n' \
        "$WORKTREE_BRANCH" "$ADAPT_REPOSITORY_DIR" >&2
    printf 'Fetch the branch, or set ADAPT_WORKTREE_DIR to an existing worktree.\n' >&2
    exit 1
fi

if [[ ! -x "$REPO_ROOT/run_podman.sh" ]]; then
    printf 'error: %s is missing or is not executable\n' "$REPO_ROOT/run_podman.sh" >&2
    exit 1
fi

export ADAPT_SOURCE_DIR
export ADAPT_REF="$ADAPT_SOURCE_REF"
export ADAPT_IMAGE="${ADAPT_IMAGE:-localhost/libretexts-adapt:$WORKTREE_SLUG-worktree}"
export ADAPT_PORT="${ADAPT_PORT:-8081}"
export ADAPT_NETWORK="${ADAPT_NETWORK:-adapt-$WORKTREE_SLUG-local}"
export ADAPT_APP_CONTAINER="${ADAPT_APP_CONTAINER:-adapt-$WORKTREE_SLUG-app}"
export ADAPT_DB_CONTAINER="${ADAPT_DB_CONTAINER:-adapt-$WORKTREE_SLUG-mysql}"
export ADAPT_REDIS_CONTAINER="${ADAPT_REDIS_CONTAINER:-adapt-$WORKTREE_SLUG-redis}"
export ADAPT_DB_VOLUME="${ADAPT_DB_VOLUME:-adapt-$WORKTREE_SLUG-mysql-data}"
export ADAPT_LOCAL_CONFIG="${ADAPT_LOCAL_CONFIG:-$REPO_ROOT/podman-local.yml}"
export ADAPT_COMMAND_NAME="$REPO_ROOT/run_podman-worktree.sh"

if (($# == 0)); then
    set -- up
fi

if [[ "$1" != "help" && "$1" != "-h" && "$1" != "--help" ]]; then
    printf 'Using %s\n' "$SOURCE_DESCRIPTION"
    printf 'Using URL: http://localhost:%s\n' "$ADAPT_PORT"
fi

"$REPO_ROOT/run_podman.sh" "$@"
