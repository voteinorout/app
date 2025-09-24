import OpenAI from 'openai';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { topic, length, style, cta, searchFacts } = req.body;
  const beatLength = 6; // Changed to 6-second beats for beefier segments
  const totalLength = Number(length) || 30;
  const facts = Array.isArray(searchFacts)
    ? searchFacts.filter((fact) => typeof fact === 'string' && fact.trim().length > 0)
    : [];
  const trimmedCta = typeof cta === 'string' ? cta.trim() : '';
  const factsInstruction = facts.length > 0
    ? `Weave in and lightly paraphrase these useful details if relevant: ${facts.join('; ')}.`
    : 'Ground each beat in believable, specific details without inventing statistics.';
  const finalCtaVoiceover = trimmedCta
    ? `Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to the CTA: "${trimmedCta}">`
    : 'Voiceover: <write 2-3 sentences, 25-35 words, resolving with an inspiring lead-in to a CTA you invent from the story (make it concrete and time-bound).>';
  const ctaGuideline = trimmedCta
    ? `- End with the provided CTA: "${trimmedCta}".`
    : '- End with a CTA you invent that naturally follows the story—make it specific (e.g., text a friend, sign a pledge, volunteer) and never default to vague "learn more" language.';
  const prompt = `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${style || 'lighthearted and comedic'} tone.

Break the script into time-stamped beats of roughly ${beatLength} seconds each using this exact layout and headings:

0-${beatLength}s: [hook]
Voiceover: <write 2-3 vivid sentences, 25-35 words, that spark curiosity with a conversational question>
Visuals: <describe dynamic supporting footage in one detailed sentence>

${beatLength}-${beatLength * 2}s: [next beat]
Voiceover: <write 2-3 sentences, 25-35 words, escalating the idea with creative benefits or scenarios>
Visuals: <describe dynamic supporting footage in one detailed sentence>

${beatLength * 2}-${beatLength * 3}s: [next beat]
Voiceover: <write 2-3 sentences, 25-35 words, further escalating with witty or unexpected scenarios>
Visuals: <describe dynamic supporting footage in one detailed sentence>

${beatLength * 3}-${beatLength * 4}s: [twist]
Voiceover: <write 2-3 sentences, 25-35 words, introducing a doubt or reality check with humor>
Visuals: <describe dynamic supporting footage in one detailed sentence>

${beatLength * 4}-${totalLength}s: [payoff/CTA]
${finalCtaVoiceover}
Visuals: <describe dynamic supporting footage in one detailed sentence>

Guidelines:
- Create a narrative arc: Start with a hook question, build through escalating creative ideas, add a twist (e.g., addressing a doubt), and end with a payoff/CTA.
- Use sharp humor, puns, and fluid, non-repetitive metaphors tailored to the topic.
- Voiceover must flow as complete sentences — no bullet fragments.
- Visuals should suggest clear, vivid shots or actions that match the voiceover.
- Never mention on-screen text or captions.
- ${factsInstruction}
- Avoid repetitive phrasing (e.g., no overusing 'imagine' or similar terms).
- Keep the tone ${style || 'lighthearted and comedic'}, fostering engagement without misleading claims.
- ${ctaGuideline}

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
