# app

Main app for VoteInOut — includes script generation, video tools, and civic engagement features, with more coming soon.

## Architecture overview

- **Flutter client** (`app/flutter_app`): UI, local transcription, and script generation logic. Talks to a proxy endpoint defined at build time.
- **Node API** (`app/api`): Vercel-ready serverless handler for OpenAI/Serper. Contains Jest tests under `api/test`.
- **Proxy requirement**: The Flutter build never embeds API keys. It now defaults to the hosted proxy at `https://vioo-app.vercel.app/api/generate-script`, but you can override it via `SCRIPT_PROXY_ENDPOINT`.

## Quick start (Flutter front-end)

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=SCRIPT_PROXY_ENDPOINT=https://your-vercel-app.vercel.app/api/generate-script
```

### Open the iOS Runner workspace in Xcode

```bash
cd flutter_app/ios
open Runner.xcworkspace
```

After Xcode opens, pick the **Runner** scheme and choose a simulator/device in the toolbar before pressing ⌘R.

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

- The Flutter client expects a proxy endpoint that handles OpenAI/Serper access. It defaults to the production proxy at `https://vioo-app.vercel.app/api/generate-script`, and you can override it with `--dart-define=SCRIPT_PROXY_ENDPOINT=<https://.../api/generate-script>`.
- Backend environment variables (`OPENAI_API_KEY`, `SERPER_API_KEY`, optional auth tokens) live on Vercel. The Flutter app requires only the proxy URL.
- API tests live under `api/test` (run with `npm test` after `npm install`), and Flutter unit/integration tests live under `flutter_app/test` (run with `flutter test`).

See `CONTRIBUTING.md` for developer setup and recommended pre-commit hook.
