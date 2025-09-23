# app

Main app for VoteInOut — includes script generation, video tools, and civic engagement features, with more coming soon.

## Architecture overview

- **Flutter client** (`app/flutter_app`): UI, local transcription, and script generation logic. Talks to a proxy endpoint defined at build time.
- **Node API** (`app/api`): Vercel-ready serverless handler for OpenAI/Serper. Contains Jest tests under `api/test`.
- **Proxy requirement**: The Flutter build never embeds API keys. Provide the deployed proxy URL via `SCRIPT_PROXY_ENDPOINT`.

## Quick start (Flutter front-end)

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=SCRIPT_PROXY_ENDPOINT=https://your-vercel-app.vercel.app/api/generate-script
```

## Run tests

```bash
cd flutter_app
flutter test
```

## Format code

```bash
cd flutter_app
flutter format .
```

- The Flutter client expects a proxy endpoint that handles OpenAI/Serper access. Pass it at build time with `--dart-define=SCRIPT_PROXY_ENDPOINT=<https://.../api/generate-script>` (the app asserts if this value is missing).
- Backend environment variables (`OPENAI_API_KEY`, `SERPER_API_KEY`, optional auth tokens) live on Vercel. The Flutter app requires only the proxy URL.
- API tests live under `api/test` (run with `npm test` after `npm install`), and Flutter unit/integration tests live under `flutter_app/test` (run with `flutter test`).

See `CONTRIBUTING.md` for developer setup and recommended pre-commit hook.
