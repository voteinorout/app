import OpenAI from 'openai';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, length, style, cta, searchFacts } = req.body;
  const beatLength = 5;
  const totalLength = Number(length) || 30;
  const facts = Array.isArray(searchFacts)
    ? searchFacts.filter((fact) => typeof fact === 'string' && fact.trim().length > 0)
    : [];
  const factsInstruction = facts.length > 0
    ? `Weave in and lightly paraphrase these useful details if relevant: ${facts.join('; ')}.`
    : 'Ground each beat in believable, specific details without inventing statistics.';
  const prompt = `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${style || 'any'} tone.

Break the script into time-stamped beats of roughly ${beatLength} seconds each using this exact layout and headings:

0-${beatLength}s:
Voiceover: <write 2-3 vivid sentences, 25-35 total words, that feel like a conversational hook>
Visuals/Actions: <describe dynamic supporting footage in one detailed sentence>

Continue the pattern for the remaining beats (e.g., ${beatLength}-${beatLength * 2}s) until you cover the full ${totalLength}-second run time. Keep line breaks exactly as shown above. Do not create any other sections.

Guidelines:
- Voiceover must flow as complete sentences — no bullet fragments.
- Visuals/Actions should suggest clear shots or actions that match the voiceover.
- Never mention on-screen text or captions.
- ${factsInstruction}
- ${cta ? `End the final beat with a natural lead-in to the call to action: "${cta}".` : 'End with a motivating invitation that fits the topic.'}

Return only the formatted beats in plain text.`;

  try {
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 900,
      temperature: 0.8,
    });

    res.status(200).json({ text: completion.choices[0].message.content });
  } catch (error) {
    res.status(500).json({ error: 'OpenAI generation failed', details: error.message });
  }
}
