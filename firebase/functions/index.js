const functions = require('firebase-functions');

// Callable function that returns the OpenAI API key stored in Firebase config.
exports.getOpenAiApiKey = functions.https.onCall((data, context) => {
  const key = functions.config().openai?.key;
  if (!key) {
    throw new functions.https.HttpsError(
      'not-found',
      'OpenAI API key is not configured. Set it with `firebase functions:config:set openai.key="YOUR_KEY"`.'
    );
  }

  return { openaiKey: key };
});
