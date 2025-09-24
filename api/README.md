# API Documentation
This directory contains a Node.js backend to proxy OpenAI/Serper calls for the Flutter app.
- `generate-script.js`: Handles POST requests with `topic`, `length`, `style`, and `cta`.
- Run with `node generate-script.js` after setting `OPENAI_API_KEY` and `SERPER_API_KEY` in `.env`.
- Deploy to a secure host (e.g., Vercel) and update the Flutter app to use the deployed URL.
