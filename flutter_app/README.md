# Vioo App (minimal Flutter scaffold)

This folder contains a minimal Flutter app scaffold created to get you started quickly.

Files created:
- `pubspec.yaml` - project metadata and dependencies
- `lib/main.dart` - minimal app with a single page and a test button

How to run
1. Install Flutter SDK (see the main repo's `flutter/README.md` for instructions).
2. From this folder:

```bash
cd /Users/lisamollica/Documents/GitHub/vioo-app/flutter_app
flutter pub get
flutter run --dart-define=SCRIPT_PROXY_ENDPOINT=https://your-vercel-app.vercel.app/api/generate-script
```

Notes
- Provide a publicly accessible proxy endpoint via `SCRIPT_PROXY_ENDPOINT` using `--dart-define` (see example above). Without it the app falls back to the deterministic local generator and logs guidance in debug builds.
- This scaffold is small and intended for development only. For a full app, run `flutter create` which generates platform folders (`ios/`, `android/`, etc.).
- If you want, I can generate a complete `flutter create` project here (it will add `ios/`, `android/`, and other files). That requires Flutter installed locally or I can add the files manually.

Next steps I can do for you
- Generate full `flutter create` project files in this path.
- Add an HTTP client example that calls your Python backend (`app.py`).
- Add GitHub Actions to build the Flutter app.
