#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly REPO_ROOT

ADAPT_REPOSITORY_DIR="${ADAPT_REPOSITORY_DIR:-$REPO_ROOT/../libretexts-adapt}"
WORKTREE_BRANCH="${ADAPT_WORKTREE_BRANCH:-mastery-retakes}"
WORKTREE_DIR="${ADAPT_WORKTREE_DIR:-}"

if [[ -z "$WORKTREE_DIR" ]]; then
    WORKTREE_DIR="$(git -C "$ADAPT_REPOSITORY_DIR" worktree list --porcelain | awk \
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

if [[ ! -x "$REPO_ROOT/run_podman.sh" ]]; then
    printf 'error: %s is missing or is not executable\n' "$REPO_ROOT/run_podman.sh" >&2
    exit 1
fi

export ADAPT_SOURCE_DIR="$WORKTREE_DIR"
export ADAPT_REF=WORKTREE
export ADAPT_IMAGE="${ADAPT_IMAGE:-localhost/libretexts-adapt:mastery-worktree}"
export ADAPT_PORT="${ADAPT_PORT:-8081}"
export ADAPT_NETWORK="${ADAPT_NETWORK:-adapt-mastery-local}"
export ADAPT_APP_CONTAINER="${ADAPT_APP_CONTAINER:-adapt-mastery-app}"
export ADAPT_DB_CONTAINER="${ADAPT_DB_CONTAINER:-adapt-mastery-mysql}"
export ADAPT_REDIS_CONTAINER="${ADAPT_REDIS_CONTAINER:-adapt-mastery-redis}"
export ADAPT_DB_VOLUME="${ADAPT_DB_VOLUME:-adapt-mastery-mysql-data}"
export ADAPT_LOCAL_CONFIG="${ADAPT_LOCAL_CONFIG:-$REPO_ROOT/podman-local.yml}"
export ADAPT_COMMAND_NAME="$REPO_ROOT/run_podman-worktree.sh"

if (($# == 0)); then
    set -- up
fi

if [[ "$1" != "help" && "$1" != "-h" && "$1" != "--help" ]]; then
    printf 'Using worktree: %s (%s)\n' "$WORKTREE_DIR" "$WORKTREE_BRANCH"
    printf 'Using URL: http://localhost:%s\n' "$ADAPT_PORT"
fi

"$REPO_ROOT/run_podman.sh" "$@"
