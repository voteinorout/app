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
  const normalizedStyle = rawStyle.toLowerCase();
  const isEducationalStyle = normalizedStyle === 'educational';
  const defaultTemperature = isEducationalStyle ? 2 : 6;
  const rawTemperature = Number.isFinite(parsedTemperature) ? parsedTemperature : defaultTemperature;
  const clampedTemperature = Math.max(0, Math.min(10, rawTemperature));
  const openAiTemperature = Number((clampedTemperature / 10).toFixed(2));
  const styleDisplay = isEducationalStyle
    ? 'clear, direct, and factual'
    : rawStyle.length === 0
      ? 'straightforward and authentic'
      : rawStyle;
  const styleDirective = isEducationalStyle
    ? 'use only clear, direct, and factual language with no metaphors, analogies, or figurative expressions, like a trusted expert delivering straightforward information to a concerned audience'
    : rawStyle.length === 0
      ? 'use clear, direct language that feels real and grounded, like a trusted friend speaking plainly'
      : `write in a ${normalizedStyle} tone, keeping it natural and conversational`;
  const factsInstruction = facts.length > 0
    ? `Heavily incorporate all provided facts into the script, using them as the core of each beat. Quote each number, date, name, or statistic plainly and exactly at least once, and reference or reuse facts multiple times across beats to build a detailed, evidence-based narrative. Do not paraphrase numbers or key details, and never invent new data. Facts: ${facts.join('; ')}.`
    : 'Ground each beat in believable, specific, verifiable details (stats, dates, names) without inventing data.';
  const finalCtaVoiceover = trimmedCta
    ? `Voiceover: <write 2-3 sentences, 25-35 words, resolving with ${isEducationalStyle ? 'a clear, fact-based' : 'an inspiring'} lead-in to the CTA: "${trimmedCta}">`
    : `Voiceover: <write 2-3 sentences, 25-35 words, resolving with ${isEducationalStyle ? 'a clear, fact-based' : 'an inspiring'} lead-in to a CTA you invent from the story (make it concrete, time-bound, and action-oriented).>`;
  const ctaGuideline = trimmedCta
    ? `- End with the provided CTA: "${trimmedCta}".`
    : '- End with a CTA you invent that naturally follows the story—make it specific (e.g., text a friend, sign a pledge, volunteer) and never default to vague "learn more" language.';
  const educationalCtaInstruction = trimmedCta
    ? `Use the provided CTA "${trimmedCta}" exactly. In the Final CTA beat, weave it into 2-3 clear, action-oriented sentences (25-35 words total) with a fact-based lead-in, focusing on specific, measurable outcomes.`
    : 'Invent a CTA that is concrete, time-bound, and measurable. In the Final CTA beat, weave it into 2-3 clear, action-oriented sentences (25-35 words total) with a fact-based lead-in.';
  const baseBeats = `Break the story into these exact beats and label each with its timestamp:
- Hook (0-6s) — deliver a bold opener that makes ${topic} impossible to ignore, starting with a key fact or stat from the provided facts.
- Spark (6-12s) — explain the catalyst or stakes driving urgency right now, incorporating at least one fact or stat.
- Proof (12-18s) — present the evidence, stat, or lived moment that makes the story undeniable, using multiple facts or stats.
- Turn (18-24s) — pivot toward the hopeful path forward and show who is already driving it, backed by relevant facts or stats.
- Final CTA (24-30s) — land the CTA with urgency, clarity, and emotional payoff, reinforced with a key fact or stat.`;

  const formatInstructions = (visualsLine) => `For each beat, output exactly this format:

**Hook (0-6s):**
Voiceover: <2-3 sentences, 25-35 words, clear and conversational, including at least one stat or fact to drive the story forward>
Visuals: <${visualsLine}>`;

  const educationalGuidelines = `Guidelines:
- Use direct, conversational language, avoiding rhetorical questions, puns, metaphors, analogies, or figurative language (no playful imagery).
- Prioritize verifiable facts (numbers, dates, names) over narrative flair.
- Tailor to a U.S. audience focused on state rights and democracy.
- Voiceover must use complete sentences; never bullet fragments.
- Visuals should be simple, authentic shots that align with the voiceover.
- Never mention on-screen text or captions.
- **${factsInstruction}**
- Avoid repetitive words or clichéd openers like "imagine" or "picture."
- Always ${styleDirective}.
- **${educationalCtaInstruction}**
- Keep each beat concise and literal while following the specified voiceover/visuals structure.`;

  const defaultGuidelines = `Guidelines:
- Use direct, conversational language; avoid rhetorical questions or overly poetic phrasing.
- Keep it fact-heavy, concise, and specific—spell out dates, names, and laws clearly.
- Tailor to a U.S. audience focused on state rights and democracy.
- Voiceover must use complete sentences; never bullet fragments.
- Visuals should suggest simple, grounded shots that match the voiceover.
- Never mention on-screen text or captions.
- **${factsInstruction}**
- Avoid repetitive words or clichéd openers like "imagine" or "picture."
- Always ${styleDirective}.
- **${ctaGuideline} In the Final CTA beat, weave the CTA into 2-3 clear, action-oriented sentences (25-35 words total). Include all specifics like names, actions, or tags, supported by a stat if possible.**
- Keep each beat tight and fact-dense while following the specified voiceover/visuals structure.`;

  const prompt = isEducationalStyle
    ? `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${styleDisplay} tone.

${baseBeats}

${formatInstructions('realistic, straightforward footage that directly supports the voiceover’s factual content, avoiding playful or exaggerated imagery')}

Every beat must connect to the previous one, forming a cohesive narrative that feels like one story. Make the script fact-driven, using the provided facts as the primary content for each beat.

${educationalGuidelines}

Return only the formatted beats in plain text.`
    : `You are a campaign storyteller crafting a ${totalLength}-second video script about "${topic}" in a ${styleDisplay} tone.

${baseBeats}

${formatInstructions('vivid, grounded footage')}

Every beat must connect to the previous one, forming a cohesive narrative that feels like one story. Make the script fact-driven, using the provided facts as the primary content for each beat.

${defaultGuidelines}

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
