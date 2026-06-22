export type HarnessModelTier = "opus" | "sonnet" | "haiku";

const DEFAULT_AGENT_MODEL = "openai-codex/gpt-5.5";

/**
 * Map old harness tier names to real Pi model IDs.
 * Override with PI_AGENT_MODEL_OPUS / _SONNET / _HAIKU or PI_AGENT_MODEL.
 */
export function modelForTier(tier: HarnessModelTier | string): string {
	const normalized = tier.toUpperCase().replace(/[^A-Z0-9]+/g, "_");
	return process.env[`PI_AGENT_MODEL_${normalized}`]
		|| process.env.PI_AGENT_MODEL
		|| DEFAULT_AGENT_MODEL;
}

export function modelForChild(ctx: { model?: { provider?: string; id?: string } } | undefined): string {
	const current = ctx?.model;
	if (current?.provider && current?.id) return `${current.provider}/${current.id}`;
	if (current?.id) return current.id;
	return process.env.PI_AGENT_MODEL || DEFAULT_AGENT_MODEL;
}
