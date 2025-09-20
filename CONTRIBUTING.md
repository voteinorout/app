# Contributing

Thanks for contributing to the Vioo app. This file explains the minimal developer workflow for running tests and keeping code formatted.

Run tests locally

```bash
cd flutter_app
flutter pub get
flutter test
```

Format code

```bash
cd flutter_app
flutter format .
```

Install the pre-commit hook (optional but recommended)

From the repository root run:

```bash
chmod +x tools/pre-commit.sh
ln -s ../../tools/pre-commit.sh .git/hooks/pre-commit
```

What the hook does
- Runs `flutter format .` before each commit to keep commits fast.
- If formatting produced changes the hook will abort the commit so you can review and stage them.

Analysis (`flutter analyze`) is enforced in CI for pull requests, so run it locally before opening a PR to avoid CI failures.

CI behavior
- A fast CI job runs on pushes and PRs and executes tests.
- A full matrix runs on PRs and performs analysis and coverage. `flutter analyze` is enforced for PRs.

If you'd prefer CI to auto-format branches, open an issue to discuss — right now the CI will not auto-push formatting commits.
