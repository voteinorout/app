# app
Main app for VoteInOut — includes script generation, video tools, and civic engagement features, with more coming soon.

Quick start (Flutter front-end)

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=SCRIPT_PROXY_ENDPOINT=https://your-vercel-app.vercel.app/api/generate-script
```

Run tests

```bash
cd flutter_app
flutter test
```

Format code

```bash
cd flutter_app
flutter format .
```

The Flutter client expects a proxy endpoint that handles OpenAI/Serper access. Pass it at build time with `--dart-define=SCRIPT_PROXY_ENDPOINT=<https://.../api/generate-script>` (the app asserts if this value is missing).

See `CONTRIBUTING.md` for developer setup and recommended pre-commit hook.
