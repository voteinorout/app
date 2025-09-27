import OpenAI from 'openai';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, style, cta, searchFacts } = req.body;
  const totalLength = 30; // Hardcoded five-beat arc
  const facts = Array.isArray(searchFacts)
    ? searchFacts.filter((fact) => typeof fact === 'string' && fact.trim().length > 0)
    : [];
  const trimmedCta = typeof cta === 'string' ? cta.trim() : '';
  const rawStyle = typeof style === 'string' ? style.trim() : '';
  const styleDisplay = rawStyle.length === 0 ? 'lighthearted and comedic' : rawStyle;
  const styleDirective = rawStyle.length === 0
    ? 'keep it quick, warm, and a little mischievous'
    : `make every line feel ${rawStyle.toLowerCase()}`;
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
- Hook (0-6s) — earn the scroll-stopping moment with a bold, curiosity-spiking opener.
- Spark (6-12s) — reveal the catalyst or stakes that make the hook matter right now.
- Proof (12-18s) — show the concrete evidence, stat, or lived moment that makes the story undeniable.
- Turn (18-24s) — pivot toward the hopeful path forward, hinting at how momentum builds.
- Final CTA (24-30s) — deliver the CTA with urgency, clarity, and emotional payoff.

For each beat, output exactly this format:

**Hook (0-6s):**  
Voiceover: <3-4 sentences, 35-45 words, propelling the story forward with vivid specificity>  
Visuals: <one dynamic sentence suggesting kinetic supporting footage>

Every beat must explicitly acknowledge or escalate what came before so the script reads as one continuous narrative when combined.

Guidelines:
- Use sharp humor, puns, and fluid, non-repetitive metaphors tailored to the topic.
- Voiceover must flow as complete sentences—never bullet fragments.
- Visuals should suggest clear, vivid shots or actions that match the voiceover.
- Never mention on-screen text or captions.
- **${factsInstruction}**
- Avoid repetitive phrasing (no overusing "imagine" or similar openers).
- Always ${styleDirective}, keeping engagement high without misleading claims.
- **${ctaGuideline} In the Final CTA beat, fully incorporate every detail from the provided CTA by paraphrasing it into 2-3 inspiring, action-oriented sentences (25-35 words total). Do not generalize or omit specifics like names, actions, or tags—integrate them seamlessly for a concrete, urgent call to action.**

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
