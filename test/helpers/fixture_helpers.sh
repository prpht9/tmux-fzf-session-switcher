#!/usr/bin/env bash
# Creates a reproducible git fixture tree for integration tests.
# Run inside container: bash /opt/tfss/test/helpers/fixture_helpers.sh
set -euo pipefail

BASE="/root/work"

# Clean slate
rm -rf "$BASE"
mkdir -p "$BASE"

# --- Normal repos ---
git init "$BASE/normal-repo"
(cd "$BASE/normal-repo" && touch README && git add . && git commit -m "init")

git init "$BASE/dotted.repo"
(cd "$BASE/dotted.repo" && touch README && git add . && git commit -m "init")

# Nested repo at depth 3 (within max-depth 4 from $BASE)
mkdir -p "$BASE/org/proj"
git init "$BASE/org/proj/nested-repo"
(cd "$BASE/org/proj/nested-repo" && touch README && git add . && git commit -m "init")

# --- Too-deep repo (depth 6 from $BASE — must NOT be found at max-depth 4) ---
mkdir -p "$BASE/too/deep/a/b/c"
git init "$BASE/too/deep/a/b/c/repo"
(cd "$BASE/too/deep/a/b/c/repo" && touch README && git add . && git commit -m "init")

# --- Not a repo (no .git) ---
mkdir -p "$BASE/not-a-repo"

# --- Bare clone + worktrees ---
# Seed a temporary repo with a commit so we can clone --bare
SEED=$(mktemp -d)
git init "$SEED"
(cd "$SEED" && touch README && git add . && git commit -m "seed")

git clone --bare "$SEED" "$BASE/myproject.bare"

# Create worktrees as siblings to the bare repo
git -C "$BASE/myproject.bare" worktree add "$BASE/mp-main" HEAD
git -C "$BASE/myproject.bare" worktree add -b feature "$BASE/mp-feature" HEAD

rm -rf "$SEED"

echo "Fixtures created under $BASE"
