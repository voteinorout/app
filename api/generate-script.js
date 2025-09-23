const OpenAI = require('openai');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, length, style, searchFacts } = req.body;

  // Build prompt (adapt from your local_llm_service.dart logic)
  const prompt = `Generate a viral video script for "${topic}" in ${style || 'any'} style, length about ${length} seconds, using hooks every 3 seconds. Structure as timed beats: 0-3s: [hook], etc. Include voiceover, text, visuals. End with CTA. Paraphrase facts: ${searchFacts ? searchFacts.join(', ') : ''}. Respond in plain text.`;

  try {
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',  // Cheap and fast; swap to 'gpt-4o' if needed
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
    });

    res.status(200).json({ text: completion.choices[0].message.content });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'OpenAI generation failed' });
  }
};