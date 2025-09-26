import OpenAI from 'openai';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, length, style, cta, searchFacts } = req.body;
  const beatLength = 4; // Four-second pacing keeps beats punchy
  const requestedLength = Number(length) || 30;
  const totalLength = Math.max(4, Math.min(90, Math.round(requestedLength)));
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
    ? `Weave in and lightly paraphrase these useful details if relevant: ${facts.join('; ')}.`
    : 'Ground each beat in believable, specific details without inventing statistics.';
  const finalCtaVoiceover = trimmedCta
    ? `Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to the CTA: "${trimmedCta}">`
    : 'Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to a CTA you invent from the story (make it concrete and time-bound).>';
  const ctaGuideline = trimmedCta
    ? `- End with the provided CTA: "${trimmedCta}".`
    : '- End with a CTA you invent that naturally follows the story—make it specific (e.g., text a friend, sign a pledge, volunteer) and never default to vague "learn more" language.';
  const prompt = `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${styleDisplay} tone.

**Break the script into time-stamped beats of roughly ${beatLength} seconds. Start at 0-${beatLength}s, then ${beatLength}-${beatLength * 2}s, ${beatLength * 2}-${beatLength * 3}s, and so on. Keep adding beats in ${beatLength}-second increments until you reach ${totalLength}s with no gaps. If the final segment would overshoot the total length, create a last beat that ends exactly at ${totalLength}s (e.g., 88-90s). Do not merge multiple segments into a single beat.**

For every beat you write, follow this structure:

**start-end s:**  
Voiceover: <2-3 sentences, 25-35 words, propelling the story forward>  
Visuals: <one detailed sentence suggesting dynamic supporting footage>

- The opening beat delivers a provocative hook.  
- Middle beats escalate the idea, explicitly referencing what came before so the narrative feels continuous. Introduce a twist/doubt once you pass the midpoint.  
- The final beat resolves the conflict and delivers the CTA.

**Guidelines:**  
- **Create a strong narrative arc: Start with a hook question that introduces the core conflict or excitement. Each subsequent beat must explicitly build on the previous one (e.g., reference or escalate an idea from the prior beat) to ensure smooth, cohesive flow—like a story unfolding chapter by chapter. Avoid jumps; make the script read as one continuous narrative when combined.**  
- Use sharp humor, puns, and fluid, non-repetitive metaphors tailored to the topic.  
- Voiceover must flow as complete sentences — no bullet fragments.  
- Visuals should suggest clear, vivid shots or actions that match the voiceover.  
- Never mention on-screen text or captions.  
- **${factsInstruction} Ensure all provided facts are woven in naturally across beats without omission, paraphrasing lightly for engagement but keeping key details intact (e.g., numbers, names, events).**  
- Avoid repetitive phrasing (e.g., no overusing 'imagine' or similar terms).  
- Always ${styleDirective}, keeping engagement high without misleading claims.  
- **${ctaGuideline} In the payoff/CTA beat, fully incorporate every detail from the provided CTA by paraphrasing it into 2-3 inspiring, action-oriented sentences (25-35 words total). Do not generalize or omit specifics like names, actions, or tags—integrate them seamlessly for a concrete, urgent call to action.**  

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
