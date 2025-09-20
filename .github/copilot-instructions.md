<!-- GitHub Copilot / AI agent instructions for the Vioo (VoteInOut) app repository -->
# Vioo (VoteInOut) — AI agent instructions

Purpose: help an AI coding agent become productive quickly in this repository. Keep changes small, visible, and follow existing Flutter conventions in `flutter_app/`.

- Project layout (quick):
  - `flutter_app/` — minimal Flutter scaffold. Key files: `lib/main.dart`, `pubspec.yaml`, `test/widget_test.dart`.
  - Platform folders (`android/`, `ios/`, `macos/`, `windows/`, `linux/`) exist under `flutter_app/` as a minimal scaffold; most development happens in `lib/`.
  - Root `README.md` — short project description.

- Big picture architecture and intent:
  - This repository hosts a small Flutter front-end prototype for VoteInOut (UI + demo flow). The app is intentionally minimal: a single-page `HomePage` with a demo button in `lib/main.dart`.
  - There are references to backend integration (mention of `app.py` in docs). No backend code is present — assume front-end HTTP clients will call an external API when added.

- Developer workflows (essential commands):
  - Install Flutter and run from `flutter_app/`:

    - `cd flutter_app`
    - `flutter pub get`
    - `flutter run` (select target platform; macOS/iOS require Xcode; Android requires Android SDK)

  - Run tests:
    - `cd flutter_app`
    - `flutter test` (runs `test/widget_test.dart`)

- Project-specific conventions and patterns:
  - Keep UI code inside `flutter_app/lib/`. Small, single-file widgets are acceptable for this scaffold. When adding features, prefer creating logical subfolders under `lib/` (e.g., `lib/screens`, `lib/widgets`, `lib/services`).
  - Depend on `pubspec.yaml` versions as-is; avoid upgrading Flutter SDK constraints without testing across platforms.
  - The codebase uses null-safety (Dart >=2.17). Follow nullable type patterns used in `lib/main.dart`.

- Integration points & notes for AI edits:
  - There is an implicit external API (not checked in). If you add HTTP client code, create a `lib/services/api.dart` with a small wrapper and document the expected base URL in `flutter_app/README.md`.
  - Keep changes incremental: make small PRs adding one widget, service, or test at a time. The scaffold is often used for demos.

- Files to reference when making edits (examples):
  - `flutter_app/lib/main.dart` — app entry + example UI pattern.
  - `flutter_app/pubspec.yaml` — dependencies and SDK constraints.
  - `flutter_app/test/widget_test.dart` — example widget test structure.
  - `flutter_app/README.md` — run instructions and notes.

- When writing code or tests:
  - Make unit / widget tests under `flutter_app/test/` and keep them fast and deterministic.
  - For network-related code, add a small abstraction (`ApiClient`) and mock it in tests.

- Merge guidance (for PRs by AI):
  - Provide a short PR description that contains:
    1) files changed and why (one-line),
    2) how to run locally (commands),
    3) any manual verification steps (tap button, see snackbar, run tests).

- Known limitations & assumptions discovered in repo:
  - No backend or CI workflows present. Assume developer will run locally.
  - This scaffold is minimal by design — avoid large refactors unless requested.

If anything above is unclear or you need more targeted instructions (e.g., specific API schemas, CI, or mobile platform build steps), ask the repo owner for missing artifacts and I'll iterate.
