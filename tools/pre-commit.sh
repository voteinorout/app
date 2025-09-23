#!/usr/bin/env bash
# Simple, fast pre-commit hook for the Vioo flutter_app
# Only runs the formatter to keep commits fast; analysis runs in CI for PRs.
set -e

ROOT_DIR=$(git rev-parse --show-toplevel)
if [ -d "$ROOT_DIR/app/flutter_app" ]; then
  cd "$ROOT_DIR/app/flutter_app" || exit 1
else
  cd "$ROOT_DIR/flutter_app" || exit 1
fi

echo "Running flutter format..."
flutter format .

# If formatting produced changes, abort the commit so the developer can review and add them.
if [ -n "$(git status --porcelain)" ]; then
	echo "Formatting produced changes. Please 'git add' the formatted files and re-run commit."
	exit 1
fi

echo "Pre-commit formatting passed."
