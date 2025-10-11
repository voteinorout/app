import OpenAI from 'openai';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, style, cta, searchFacts, temperature } = req.body;
  const totalLength = 30; // Hardcoded five-beat arc
  const facts = Array.isArray(searchFacts)
    ? searchFacts.filter((fact) => typeof fact === 'string' && fact.trim().length > 0)
    : [];
  const trimmedCta = typeof cta === 'string' ? cta.trim() : '';
  const rawStyle = typeof style === 'string' ? style.trim() : '';
  const parsedTemperature = Number(temperature);
  const rawTemperature = Number.isFinite(parsedTemperature) ? parsedTemperature : 6;
  const clampedTemperature = Math.max(0, Math.min(10, rawTemperature));
  const openAiTemperature = Number((clampedTemperature / 10).toFixed(2));
  const styleDisplay = rawStyle.length === 0 ? 'straightforward and authentic' : rawStyle;
  const styleDirective = rawStyle.length === 0
    ? 'use clear, direct language that feels real and grounded, like a trusted friend speaking plainly'
    : `write in a ${rawStyle.toLowerCase()} tone, keeping it natural and conversational`;
  const factsInstruction = facts.length > 0
    ? `Integrate every one of these facts somewhere in the script, quoting each number or named detail plainly and exactly once: ${facts.join('; ')}. Do not paraphrase away the numbers, and never invent new data.`
    : 'Ground each beat in believable, specific, verifiable details without inventing statistics.';
  const finalCtaVoiceover = trimmedCta
    ? `Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to the CTA: "${trimmedCta}">`
    : 'Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to a CTA you invent from the story (make it concrete and time-bound).>';
  const ctaGuideline = trimmedCta
    ? `- End with the provided CTA: "${trimmedCta}".`
    : '- End with a CTA you invent that naturally follows the story—make it specific (e.g., text a friend, sign a pledge, volunteer) and never default to vague "learn more" language.';
  const prompt = `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${styleDisplay} tone.

Break the story into these exact beats and include each label with its timestamp:
- Hook (0-6s) — grab attention with a clear, bold statement that feels real and relatable.
- Spark (6-12s) — show why this matters now, using plain language to highlight urgency or stakes.
- Proof (12-18s) — share a specific fact, story, or moment that grounds the issue in reality.
- Turn (18-24s) — shift to a clear, hopeful action or stand, showing people taking control.
- Final CTA (24-30s) — deliver the CTA with directness, urgency, and emotional weight.

For each beat, output exactly this format:

**Hook (0-6s):**  
Voiceover: <2-3 sentences, 25-35 words, clear and conversational, driving the story forward>  
Visuals: <one concise sentence suggesting vivid, grounded footage>

Every beat must connect to the previous one, forming a cohesive narrative that feels like one story.

Guidelines:
- Use direct, conversational language, avoiding rhetorical questions, puns, or overly poetic phrasing.
- Keep it fact-heavy, concise, and specific, spelling out dates, names, and laws clearly.
- Tailor to a U.S. audience focused on state rights and democracy, emphasizing urgency and clarity.
- Voiceover must use complete sentences, never fragments or bullet points.
- Visuals should suggest simple, authentic shots that match the voiceover’s tone.
- Never mention on-screen text or captions.
- **${factsInstruction}**
- Avoid repetitive words or clichéd openers like "imagine" or "picture."
- Always ${styleDirective}, keeping the tone grounded and engaging without exaggeration.
- **${ctaGuideline} In the Final CTA beat, weave the CTA into 2-3 clear, action-oriented sentences (25-35 words total). Include all specifics like names, actions, or tags, delivering a direct, urgent call to action.**

Return only the formatted beats in plain text.`;

  try {
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 900,
      temperature: openAiTemperature,
    });

    res.status(200).json({ text: completion.choices[0].message.content });
  } catch (error) {
    res.status(500).json({ error: 'OpenAI generation failed', details: error.message });
  }
}
