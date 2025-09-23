# Firebase backend setup

1. Install the Firebase CLI (`npm install -g firebase-tools`) and log in (`firebase login`).
2. Initialise functions (or add these files to an existing project) and set the OpenAI key:
   ```bash
   firebase functions:config:set openai.key="YOUR_OPENAI_KEY"
   firebase deploy --only functions:getOpenAiApiKey
   ```
3. Optionally set a Serper API key for search lookups:
   ```bash
   firebase functions:config:set serper.key="YOUR_SERPER_KEY"
   ```
4. Update `firebase_options.dart` by running `flutterfire configure` so the mobile app can connect to your Firebase project.
