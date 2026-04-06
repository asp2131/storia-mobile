/**
 * Agent Team — Storia Harness-Aware Orchestrator
 *
 * Integrates the full storia agent ecosystem:
 *   - Three-tier hierarchy: Orchestrator → Leads → Workers
 *   - Expertise hotloading from .pi/expertise/*.md
 *   - Model rotation per agent tier (opus/sonnet/haiku)
 *   - Pipeline chains from .pi/agents/agent-chain.yaml
 *   - Evolution tracking (metrics, failures, changelog)
 *   - Tier-grouped grid dashboard
 *
 * Loads agents from agents/*.md, .claude/agents/*.md, .pi/agents/*.md,
 * and .pi/agents/storia-team/*.md.
 * Teams from .pi/agents/teams.yaml. Harness protocols from .pi/harness/.
 *
 * Commands:
 *   /agents-team          — switch active team
 *   /agents-list          — list loaded agents with tier/model info
 *   /agents-grid N        — set column count (default 2)
 *   /agents-metrics       — show evolution metrics
 *
 * Usage: pi -e extensions/agent-team.ts
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text, type AutocompleteItem, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { spawn } from "child_process";
import { readdirSync, readFileSync, existsSync, mkdirSync, unlinkSync, writeFileSync } from "fs";
import { join, resolve } from "path";
import { applyExtensionDefaults } from "./themeMap.ts";

// ── Types ────────────────────────────────────────

type AgentTier = "orchestrator" | "lead" | "worker" | "validator" | "meta";
type ModelTier = "opus" | "sonnet" | "haiku";

interface AgentDef {
	name: string;
	description: string;
	tools: string;
	systemPrompt: string;
	file: string;
	model: ModelTier;
	tier: AgentTier;
	skills: string[];
}

interface AgentState {
	def: AgentDef;
	status: "idle" | "running" | "done" | "error";
	task: string;
	toolCount: number;
	elapsed: number;
	lastWork: string;
	contextPct: number;
	sessionFile: string | null;
	runCount: number;
	failCount: number;
	currentModel: ModelTier;
	timer?: ReturnType<typeof setInterval>;
}

interface ChainStep {
	agent: string;
	prompt: string;
}

interface ChainDef {
	description: string;
	steps: ChainStep[];
}

interface EvolutionMetrics {
	evolution_cycle: number;
	date: string;
	total_tasks_completed: number;
	total_worker_failures: number;
	total_lead_takeovers: number;
	total_patterns_added: number;
	total_patterns_pruned: number;
	total_prompt_changes: number;
	expertise_tokens: Record<string, number>;
}

interface FailureEntry {
	timestamp: string;
	agent: string;
	task: string;
	original_model: string;
	rotated_to: string | null;
	reason: string;
	outcome: "success" | "failed" | "escalated";
}

// ── Display Name Helper ──────────────────────────

function displayName(name: string): string {
	return name.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
}

// ── Teams YAML Parser ────────────────────────────

function parseTeamsYaml(raw: string): Record<string, string[]> {
	const teams: Record<string, string[]> = {};
	let current: string | null = null;
	for (const line of raw.split("\n")) {
		const teamMatch = line.match(/^(\S[^:]*):$/);
		if (teamMatch) {
			current = teamMatch[1].trim();
			teams[current] = [];
			continue;
		}
		const itemMatch = line.match(/^\s+-\s+(.+)$/);
		if (itemMatch && current) {
			teams[current].push(itemMatch[1].trim());
		}
	}
	return teams;
}

// ── Chain YAML Parser ────────────────────────────

function parseChainsYaml(raw: string): Record<string, ChainDef> {
	const chains: Record<string, ChainDef> = {};
	let currentChain: string | null = null;
	let currentStep: Partial<ChainStep> | null = null;
	let inSteps = false;
	let descBuffer = "";

	for (const line of raw.split("\n")) {
		// Top-level chain key (not indented, ends with colon)
		const chainMatch = line.match(/^(\S[^:]*):$/);
		if (chainMatch) {
			// Save previous step
			if (currentStep?.agent && currentStep?.prompt && currentChain) {
				chains[currentChain].steps.push(currentStep as ChainStep);
			}
			currentChain = chainMatch[1].trim();
			chains[currentChain] = { description: "", steps: [] };
			currentStep = null;
			inSteps = false;
			descBuffer = "";
			continue;
		}

		if (!currentChain) continue;

		// Description field
		const descMatch = line.match(/^\s+description:\s*"(.*)"\s*$/);
		if (descMatch) {
			chains[currentChain].description = descMatch[1];
			continue;
		}

		// Steps array start
		if (line.match(/^\s+steps:\s*$/)) {
			inSteps = true;
			continue;
		}

		if (!inSteps) continue;

		// New step (- agent:)
		const agentMatch = line.match(/^\s+-\s+agent:\s*(\S+)\s*$/);
		if (agentMatch) {
			// Save previous step
			if (currentStep?.agent && currentStep?.prompt) {
				chains[currentChain].steps.push(currentStep as ChainStep);
			}
			currentStep = { agent: agentMatch[1] };
			descBuffer = "";
			continue;
		}

		// Prompt field (may be multiline with \n)
		const promptMatch = line.match(/^\s+prompt:\s*"(.*)"\s*$/);
		if (promptMatch && currentStep) {
			currentStep.prompt = promptMatch[1].replace(/\\n/g, "\n");
			continue;
		}
	}

	// Save last step
	if (currentStep?.agent && currentStep?.prompt && currentChain) {
		chains[currentChain].steps.push(currentStep as ChainStep);
	}

	return chains;
}

// ── Tier Detection ───────────────────────────────

function detectTier(name: string, tools: string): AgentTier {
	const lower = name.toLowerCase();
	if (lower.includes("orchestrator")) return "orchestrator";
	if (lower.includes("self-improver")) return "meta";
	if (lower.endsWith("-lead")) return "lead";
	if (lower.includes("auditor") || lower.includes("validator")) return "validator";
	return "worker";
}

function defaultModelForTier(tier: AgentTier): ModelTier {
	switch (tier) {
		case "orchestrator": return "opus";
		case "lead": return "opus";
		case "meta": return "opus";
		case "worker": return "sonnet";
		case "validator": return "haiku";
	}
}

// ── Model Rotation ───────────────────────────────

const MODEL_ESCALATION: Record<ModelTier, ModelTier | null> = {
	haiku: "sonnet",
	sonnet: "opus",
	opus: null, // can't escalate further
};

function escalateModel(current: ModelTier): ModelTier | null {
	return MODEL_ESCALATION[current];
}

// ── Frontmatter Parser ───────────────────────────

function parseAgentFile(filePath: string): AgentDef | null {
	try {
		const raw = readFileSync(filePath, "utf-8");
		const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
		if (!match) return null;

		const frontmatter: Record<string, string> = {};
		for (const line of match[1].split("\n")) {
			const idx = line.indexOf(":");
			if (idx > 0) {
				frontmatter[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
			}
		}

		if (!frontmatter.name) return null;

		const tools = frontmatter.tools || "read,grep,find,ls";
		const tier = detectTier(frontmatter.name, tools);
		const model = (frontmatter.model as ModelTier) || defaultModelForTier(tier);

		// Parse skills list
		const skills: string[] = [];
		const skillsMatch = match[1].match(/skills:\s*\n((?:\s+-\s+.+\n?)*)/);
		if (skillsMatch) {
			for (const sLine of skillsMatch[1].split("\n")) {
				const sm = sLine.match(/^\s+-\s+(.+)$/);
				if (sm) skills.push(sm[1].trim());
			}
		}

		return {
			name: frontmatter.name,
			description: frontmatter.description || "",
			tools,
			systemPrompt: match[2].trim(),
			file: filePath,
			model,
			tier,
			skills,
		};
	} catch {
		return null;
	}
}

function scanAgentDirs(cwd: string): AgentDef[] {
	const dirs = [
		join(cwd, "agents"),
		join(cwd, ".claude", "agents"),
		join(cwd, ".pi", "agents"),
		join(cwd, ".pi", "agents", "storia-team"),
	];

	const agents: AgentDef[] = [];
	const seen = new Set<string>();

	for (const dir of dirs) {
		if (!existsSync(dir)) continue;
		try {
			for (const file of readdirSync(dir)) {
				if (!file.endsWith(".md")) continue;
				const fullPath = resolve(dir, file);
				const def = parseAgentFile(fullPath);
				if (def && !seen.has(def.name.toLowerCase())) {
					seen.add(def.name.toLowerCase());
					agents.push(def);
				}
			}
		} catch {}
	}

	return agents;
}

// ── Expertise Loader ─────────────────────────────

function loadExpertise(cwd: string, agentName: string): string | null {
	const key = agentName.toLowerCase().replace(/\s+/g, "-");
	const expertisePath = join(cwd, ".pi", "expertise", `${key}.md`);
	if (!existsSync(expertisePath)) return null;
	try {
		const content = readFileSync(expertisePath, "utf-8").trim();
		return content || null;
	} catch {
		return null;
	}
}

// ── Evolution I/O ────────────────────────────────

function loadMetrics(cwd: string): EvolutionMetrics {
	const metricsPath = join(cwd, ".pi", "evolution", "metrics.json");
	try {
		if (existsSync(metricsPath)) {
			return JSON.parse(readFileSync(metricsPath, "utf-8"));
		}
	} catch {}
	return {
		evolution_cycle: 0,
		date: new Date().toISOString().split("T")[0],
		total_tasks_completed: 0,
		total_worker_failures: 0,
		total_lead_takeovers: 0,
		total_patterns_added: 0,
		total_patterns_pruned: 0,
		total_prompt_changes: 0,
		expertise_tokens: {},
	};
}

function saveMetrics(cwd: string, metrics: EvolutionMetrics): void {
	const metricsPath = join(cwd, ".pi", "evolution", "metrics.json");
	const dir = join(cwd, ".pi", "evolution");
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
	metrics.date = new Date().toISOString().split("T")[0];
	writeFileSync(metricsPath, JSON.stringify(metrics, null, 2) + "\n");
}

function appendFailure(cwd: string, entry: FailureEntry): void {
	const failPath = join(cwd, ".pi", "evolution", "failures.jsonl");
	const dir = join(cwd, ".pi", "evolution");
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
	writeFileSync(failPath, JSON.stringify(entry) + "\n", { flag: "a" });
}

// ── Extension ────────────────────────────────────

export default function (pi: ExtensionAPI) {
	const agentStates: Map<string, AgentState> = new Map();
	let allAgentDefs: AgentDef[] = [];
	let teams: Record<string, string[]> = {};
	let chains: Record<string, ChainDef> = {};
	let activeTeamName = "";
	let gridCols = 2;
	let widgetCtx: any;
	let sessionDir = "";
	let contextWindow = 0;
	let cwd = "";
	let metrics: EvolutionMetrics;

	function loadAgents(workingDir: string) {
		cwd = workingDir;

		// Create session storage dir
		sessionDir = join(cwd, ".pi", "agent-sessions");
		if (!existsSync(sessionDir)) {
			mkdirSync(sessionDir, { recursive: true });
		}

		// Load all agent definitions (now includes storia-team subdir)
		allAgentDefs = scanAgentDirs(cwd);

		// Load teams from .pi/agents/teams.yaml
		const teamsPath = join(cwd, ".pi", "agents", "teams.yaml");
		if (existsSync(teamsPath)) {
			try {
				teams = parseTeamsYaml(readFileSync(teamsPath, "utf-8"));
			} catch {
				teams = {};
			}
		} else {
			teams = {};
		}

		// If no teams defined, create a default "all" team
		if (Object.keys(teams).length === 0) {
			teams = { all: allAgentDefs.map(d => d.name) };
		}

		// Load pipeline chains from .pi/agents/agent-chain.yaml
		const chainPath = join(cwd, ".pi", "agents", "agent-chain.yaml");
		if (existsSync(chainPath)) {
			try {
				chains = parseChainsYaml(readFileSync(chainPath, "utf-8"));
			} catch {
				chains = {};
			}
		}

		// Load evolution metrics
		metrics = loadMetrics(cwd);
	}

	function activateTeam(teamName: string) {
		activeTeamName = teamName;
		const members = teams[teamName] || [];
		const defsByName = new Map(allAgentDefs.map(d => [d.name.toLowerCase(), d]));

		agentStates.clear();
		for (const member of members) {
			const def = defsByName.get(member.toLowerCase());
			if (!def) continue;
			const key = def.name.toLowerCase().replace(/\s+/g, "-");
			const sessionFile = join(sessionDir, `${key}.json`);
			agentStates.set(def.name.toLowerCase(), {
				def,
				status: "idle",
				task: "",
				toolCount: 0,
				elapsed: 0,
				lastWork: "",
				contextPct: 0,
				sessionFile: existsSync(sessionFile) ? sessionFile : null,
				runCount: 0,
				failCount: 0,
				currentModel: def.model,
			});
		}

		// Auto-size grid columns based on team size
		const size = agentStates.size;
		gridCols = size <= 3 ? size : size === 4 ? 2 : 3;
	}

	// ── Tier Helpers ─────────────────────────────

	function agentsByTier(): Map<AgentTier, AgentState[]> {
		const grouped = new Map<AgentTier, AgentState[]>();
		const tierOrder: AgentTier[] = ["orchestrator", "lead", "worker", "validator", "meta"];
		for (const tier of tierOrder) grouped.set(tier, []);
		for (const state of agentStates.values()) {
			const list = grouped.get(state.def.tier) || [];
			list.push(state);
			grouped.set(state.def.tier, list);
		}
		return grouped;
	}

	function tierLabel(tier: AgentTier): string {
		switch (tier) {
			case "orchestrator": return "ORCHESTRATOR";
			case "lead": return "LEADS";
			case "worker": return "WORKERS";
			case "validator": return "VALIDATORS";
			case "meta": return "META";
		}
	}

	function tierColor(tier: AgentTier): string {
		switch (tier) {
			case "orchestrator": return "accent";
			case "lead": return "success";
			case "worker": return "muted";
			case "validator": return "dim";
			case "meta": return "error";
		}
	}

	// ── Grid Rendering ───────────────────────────

	function renderCard(state: AgentState, colWidth: number, theme: any): string[] {
		const w = colWidth - 2;
		const truncate = (s: string, max: number) => s.length > max ? s.slice(0, max - 3) + "..." : s;

		const statusColor = state.status === "idle" ? "dim"
			: state.status === "running" ? "accent"
			: state.status === "done" ? "success" : "error";
		const statusIcon = state.status === "idle" ? "○"
			: state.status === "running" ? "●"
			: state.status === "done" ? "✓" : "✗";

		const name = displayName(state.def.name);
		const nameStr = theme.fg("accent", theme.bold(truncate(name, w - 8)));
		const nameVisible = Math.min(name.length, w - 8);

		// Model badge
		const modelBadge = state.currentModel.slice(0, 3).toUpperCase();
		const modelColor = state.currentModel === "opus" ? "accent"
			: state.currentModel === "sonnet" ? "success" : "dim";
		const modelStr = theme.fg(modelColor, `[${modelBadge}]`);
		const modelVisible = modelBadge.length + 2;

		const statusStr = `${statusIcon} ${state.status}`;
		const timeStr = state.status !== "idle" ? ` ${Math.round(state.elapsed / 1000)}s` : "";
		const failStr = state.failCount > 0 ? ` ↻${state.failCount}` : "";
		const statusLine = theme.fg(statusColor, statusStr + timeStr + failStr);
		const statusVisible = statusStr.length + timeStr.length + failStr.length;

		// Context bar: 5 blocks + percent
		const filled = Math.ceil(state.contextPct / 20);
		const bar = "#".repeat(filled) + "-".repeat(5 - filled);
		const ctxStr = `[${bar}] ${Math.ceil(state.contextPct)}%`;
		const ctxLine = theme.fg("dim", ctxStr);
		const ctxVisible = ctxStr.length;

		const workRaw = state.task
			? (state.lastWork || state.task)
			: state.def.description;
		const workText = truncate(workRaw, Math.min(50, w - 1));
		const workLine = theme.fg("muted", workText);
		const workVisible = workText.length;

		const top = "┌" + "─".repeat(w) + "┐";
		const bot = "└" + "─".repeat(w) + "┘";
		const border = (content: string, visLen: number) =>
			theme.fg("dim", "│") + content + " ".repeat(Math.max(0, w - visLen)) + theme.fg("dim", "│");

		return [
			theme.fg("dim", top),
			border(" " + nameStr + " " + modelStr, 1 + nameVisible + 1 + modelVisible),
			border(" " + statusLine, 1 + statusVisible),
			border(" " + ctxLine, 1 + ctxVisible),
			border(" " + workLine, 1 + workVisible),
			theme.fg("dim", bot),
		];
	}

	function updateWidget() {
		if (!widgetCtx) return;

		widgetCtx.ui.setWidget("agent-team", (_tui: any, theme: any) => {
			const text = new Text("", 0, 1);

			return {
				render(width: number): string[] {
					if (agentStates.size === 0) {
						text.setText(theme.fg("dim", "No agents found. Add .md files to .pi/agents/storia-team/"));
						return text.render(width);
					}

					const grouped = agentsByTier();
					const output: string[] = [];

					for (const [tier, agents] of grouped) {
						if (agents.length === 0) continue;

						// Tier header
						const label = tierLabel(tier);
						const color = tierColor(tier);
						const headerLine = theme.fg(color, `── ${label} `) +
							theme.fg("dim", "─".repeat(Math.max(0, width - label.length - 4)));
						output.push(headerLine);

						// Render cards in grid
						const cols = Math.min(gridCols, agents.length);
						const gap = 1;
						const colWidth = Math.floor((width - gap * (cols - 1)) / cols);

						for (let i = 0; i < agents.length; i += cols) {
							const rowAgents = agents.slice(i, i + cols);
							const cards = rowAgents.map(a => renderCard(a, colWidth, theme));

							while (cards.length < cols) {
								cards.push(Array(6).fill(" ".repeat(colWidth)));
							}

							const cardHeight = cards[0].length;
							for (let line = 0; line < cardHeight; line++) {
								output.push(cards.map(card => card[line] || "").join(" ".repeat(gap)));
							}
						}
					}

					text.setText(output.join("\n"));
					return text.render(width);
				},
				invalidate() {
					text.invalidate();
				},
			};
		});
	}

	// ── Dispatch Agent (with expertise + model rotation) ─────────

	function dispatchAgent(
		agentName: string,
		task: string,
		ctx: any,
		modelOverride?: ModelTier,
	): Promise<{ output: string; exitCode: number; elapsed: number }> {
		const key = agentName.toLowerCase();
		const state = agentStates.get(key);
		if (!state) {
			return Promise.resolve({
				output: `Agent "${agentName}" not found. Available: ${Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ")}`,
				exitCode: 1,
				elapsed: 0,
			});
		}

		if (state.status === "running") {
			return Promise.resolve({
				output: `Agent "${displayName(state.def.name)}" is already running. Wait for it to finish.`,
				exitCode: 1,
				elapsed: 0,
			});
		}

		const effectiveModel = modelOverride || state.def.model;
		state.status = "running";
		state.task = task;
		state.toolCount = 0;
		state.elapsed = 0;
		state.lastWork = "";
		state.runCount++;
		state.currentModel = effectiveModel;
		updateWidget();

		const startTime = Date.now();
		state.timer = setInterval(() => {
			state.elapsed = Date.now() - startTime;
			updateWidget();
		}, 1000);

		// Build model string — use agent's own model, not parent's
		const model = `openrouter/anthropic/claude-3.5-${effectiveModel}`;

		// Session file for this agent
		const agentKey = state.def.name.toLowerCase().replace(/\s+/g, "-");
		const agentSessionFile = join(sessionDir, `${agentKey}.json`);

		// Hotload expertise into system prompt
		const expertise = loadExpertise(cwd, state.def.name);
		let systemPrompt = state.def.systemPrompt;
		if (expertise) {
			systemPrompt += `\n\n## Expertise (auto-loaded from .pi/expertise/)\n\n${expertise}`;
		}

		// Build args — first run creates session, subsequent runs resume
		const args = [
			"--mode", "json",
			"-p",
			"--no-extensions",
			"--model", model,
			"--tools", state.def.tools,
			"--thinking", "off",
			"--append-system-prompt", systemPrompt,
			"--session", agentSessionFile,
		];

		// Continue existing session if we have one
		if (state.sessionFile) {
			args.push("-c");
		}

		args.push(task);

		const textChunks: string[] = [];

		return new Promise((resolve) => {
			const proc = spawn("pi", args, {
				stdio: ["ignore", "pipe", "pipe"],
				env: { ...process.env },
			});

			let buffer = "";

			proc.stdout!.setEncoding("utf-8");
			proc.stdout!.on("data", (chunk: string) => {
				buffer += chunk;
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) {
					if (!line.trim()) continue;
					try {
						const event = JSON.parse(line);
						if (event.type === "message_update") {
							const delta = event.assistantMessageEvent;
							if (delta?.type === "text_delta") {
								textChunks.push(delta.delta || "");
								const full = textChunks.join("");
								const last = full.split("\n").filter((l: string) => l.trim()).pop() || "";
								state.lastWork = last;
								updateWidget();
							}
						} else if (event.type === "tool_execution_start") {
							state.toolCount++;
							updateWidget();
						} else if (event.type === "message_end") {
							const msg = event.message;
							if (msg?.usage && contextWindow > 0) {
								state.contextPct = ((msg.usage.input || 0) / contextWindow) * 100;
								updateWidget();
							}
						} else if (event.type === "agent_end") {
							const msgs = event.messages || [];
							const last = [...msgs].reverse().find((m: any) => m.role === "assistant");
							if (last?.usage && contextWindow > 0) {
								state.contextPct = ((last.usage.input || 0) / contextWindow) * 100;
								updateWidget();
							}
						}
					} catch {}
				}
			});

			proc.stderr!.setEncoding("utf-8");
			proc.stderr!.on("data", () => {});

			proc.on("close", (code) => {
				if (buffer.trim()) {
					try {
						const event = JSON.parse(buffer);
						if (event.type === "message_update") {
							const delta = event.assistantMessageEvent;
							if (delta?.type === "text_delta") textChunks.push(delta.delta || "");
						}
					} catch {}
				}

				clearInterval(state.timer);
				state.elapsed = Date.now() - startTime;
				state.status = code === 0 ? "done" : "error";

				// Mark session file as available for resume
				if (code === 0) {
					state.sessionFile = agentSessionFile;
				}

				const full = textChunks.join("");
				state.lastWork = full.split("\n").filter((l: string) => l.trim()).pop() || "";
				updateWidget();

				// ── Evolution tracking ──
				if (code === 0) {
					metrics.total_tasks_completed++;
				} else {
					state.failCount++;
					if (state.def.tier === "worker" || state.def.tier === "validator") {
						metrics.total_worker_failures++;
					} else if (state.def.tier === "lead") {
						metrics.total_lead_takeovers++;
					}
					appendFailure(cwd, {
						timestamp: new Date().toISOString(),
						agent: state.def.name,
						task: task.slice(0, 200),
						original_model: state.def.model,
						rotated_to: effectiveModel !== state.def.model ? effectiveModel : null,
						reason: `exit code ${code}`,
						outcome: "failed",
					});
				}
				saveMetrics(cwd, metrics);

				ctx.ui.notify(
					`${displayName(state.def.name)} ${state.status} in ${Math.round(state.elapsed / 1000)}s`,
					state.status === "done" ? "success" : "error"
				);

				resolve({
					output: full,
					exitCode: code ?? 1,
					elapsed: state.elapsed,
				});
			});

			proc.on("error", (err) => {
				clearInterval(state.timer);
				state.status = "error";
				state.failCount++;
				state.lastWork = `Error: ${err.message}`;
				updateWidget();

				appendFailure(cwd, {
					timestamp: new Date().toISOString(),
					agent: state.def.name,
					task: task.slice(0, 200),
					original_model: effectiveModel,
					rotated_to: null,
					reason: err.message,
					outcome: "failed",
				});
				saveMetrics(cwd, metrics);

				resolve({
					output: `Error spawning agent: ${err.message}`,
					exitCode: 1,
					elapsed: Date.now() - startTime,
				});
			});
		});
	}

	// ── Dispatch with model rotation retry ───────

	async function dispatchWithRetry(
		agentName: string,
		task: string,
		ctx: any,
		maxRetries = 2,
	): Promise<{ output: string; exitCode: number; elapsed: number }> {
		const key = agentName.toLowerCase();
		const state = agentStates.get(key);
		if (!state) return dispatchAgent(agentName, task, ctx);

		let currentModel: ModelTier = state.def.model;
		let totalElapsed = 0;
		let lastResult: { output: string; exitCode: number; elapsed: number };

		for (let attempt = 0; attempt <= maxRetries; attempt++) {
			// Reset state for retry
			if (attempt > 0) {
				state.status = "idle";
				state.sessionFile = null; // fresh session for retry
				ctx.ui.notify(
					`Retrying ${displayName(state.def.name)} with ${currentModel}... (attempt ${attempt + 1})`,
					"warning"
				);
			}

			lastResult = await dispatchAgent(agentName, task, ctx, currentModel);
			totalElapsed += lastResult.elapsed;

			if (lastResult.exitCode === 0) {
				// On success after rotation, log the recovery
				if (currentModel !== state.def.model) {
					appendFailure(cwd, {
						timestamp: new Date().toISOString(),
						agent: state.def.name,
						task: task.slice(0, 200),
						original_model: state.def.model,
						rotated_to: currentModel,
						reason: `recovered after model escalation`,
						outcome: "success",
					});
				}
				return { ...lastResult, elapsed: totalElapsed };
			}

			// Try escalating model
			const next = escalateModel(currentModel);
			if (!next) break; // already at highest tier
			currentModel = next;
		}

		return { ...lastResult!, elapsed: totalElapsed };
	}

	// ── dispatch_agent Tool ──────────────────────

	pi.registerTool({
		name: "dispatch_agent",
		label: "Dispatch Agent",
		description: "Dispatch a task to a specialist agent. Automatically applies expertise hotloading and model rotation on failure.",
		parameters: Type.Object({
			agent: Type.String({ description: "Agent name (case-insensitive)" }),
			task: Type.String({ description: "Task description for the agent to execute" }),
			retry: Type.Optional(Type.Boolean({ description: "Enable model rotation retry on failure (default: true)" })),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const { agent, task, retry } = params as { agent: string; task: string; retry?: boolean };

			try {
				if (onUpdate) {
					onUpdate({
						content: [{ type: "text", text: `Dispatching to ${agent}...` }],
						details: { agent, task, status: "dispatching" },
					});
				}

				const shouldRetry = retry !== false;
				const result = shouldRetry
					? await dispatchWithRetry(agent, task, ctx)
					: await dispatchAgent(agent, task, ctx);

				const truncated = result.output.length > 8000
					? result.output.slice(0, 8000) + "\n\n... [truncated]"
					: result.output;

				const status = result.exitCode === 0 ? "done" : "error";
				const state = agentStates.get(agent.toLowerCase());
				const modelUsed = state?.currentModel || "unknown";
				const summary = `[${agent}] ${status} in ${Math.round(result.elapsed / 1000)}s (${modelUsed})`;

				return {
					content: [{ type: "text", text: `${summary}\n\n${truncated}` }],
					details: {
						agent,
						task,
						status,
						model: modelUsed,
						elapsed: result.elapsed,
						exitCode: result.exitCode,
						fullOutput: result.output,
					},
				};
			} catch (err: any) {
				return {
					content: [{ type: "text", text: `Error dispatching to ${agent}: ${err?.message || err}` }],
					details: { agent, task, status: "error", elapsed: 0, exitCode: 1, fullOutput: "" },
				};
			}
		},

		renderCall(args, theme) {
			const agentName = (args as any).agent || "?";
			const task = (args as any).task || "";
			const preview = task.length > 60 ? task.slice(0, 57) + "..." : task;
			return new Text(
				theme.fg("toolTitle", theme.bold("dispatch_agent ")) +
				theme.fg("accent", agentName) +
				theme.fg("dim", " — ") +
				theme.fg("muted", preview),
				0, 0,
			);
		},

		renderResult(result, options, theme) {
			const details = result.details as any;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			if (options.isPartial || details.status === "dispatching") {
				return new Text(
					theme.fg("accent", `● ${details.agent || "?"}`) +
					theme.fg("dim", " working..."),
					0, 0,
				);
			}

			const icon = details.status === "done" ? "✓" : "✗";
			const color = details.status === "done" ? "success" : "error";
			const elapsed = typeof details.elapsed === "number" ? Math.round(details.elapsed / 1000) : 0;
			const modelTag = details.model ? ` [${details.model}]` : "";
			const header = theme.fg(color, `${icon} ${details.agent}`) +
				theme.fg("dim", ` ${elapsed}s${modelTag}`);

			if (options.expanded && details.fullOutput) {
				const output = details.fullOutput.length > 4000
					? details.fullOutput.slice(0, 4000) + "\n... [truncated]"
					: details.fullOutput;
				return new Text(header + "\n" + theme.fg("muted", output), 0, 0);
			}

			return new Text(header, 0, 0);
		},
	});

	// ── dispatch_chain Tool ──────────────────────

	pi.registerTool({
		name: "dispatch_chain",
		label: "Dispatch Pipeline",
		description: "Run a multi-step pipeline chain. Each step's output feeds into the next step's $INPUT. Available chains are shown in the system prompt.",
		parameters: Type.Object({
			chain: Type.String({ description: "Pipeline name from agent-chain.yaml" }),
			input: Type.String({ description: "Initial input — replaces $INPUT in the first step" }),
		}),

		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			const { chain: chainName, input } = params as { chain: string; input: string };
			const chainDef = chains[chainName];

			if (!chainDef) {
				const available = Object.keys(chains).join(", ");
				return {
					content: [{ type: "text", text: `Chain "${chainName}" not found. Available: ${available}` }],
					details: { chain: chainName, status: "error" },
				};
			}

			const originalInput = input;
			let currentInput = input;
			const stepResults: Array<{ agent: string; status: string; elapsed: number; output: string }> = [];
			let totalElapsed = 0;

			for (let i = 0; i < chainDef.steps.length; i++) {
				const step = chainDef.steps[i];

				// Substitute $INPUT and $ORIGINAL
				const prompt = step.prompt
					.replace(/\$INPUT/g, currentInput)
					.replace(/\$ORIGINAL/g, originalInput);

				if (onUpdate) {
					onUpdate({
						content: [{ type: "text", text: `Step ${i + 1}/${chainDef.steps.length}: ${step.agent}...` }],
						details: { chain: chainName, step: i + 1, agent: step.agent, status: "running" },
					});
				}

				const result = await dispatchWithRetry(step.agent, prompt, ctx);
				totalElapsed += result.elapsed;

				const status = result.exitCode === 0 ? "done" : "error";
				stepResults.push({
					agent: step.agent,
					status,
					elapsed: result.elapsed,
					output: result.output,
				});

				if (result.exitCode !== 0) {
					// Chain stops on failure
					const summary = stepResults.map((r, idx) =>
						`  ${idx + 1}. ${r.agent}: ${r.status} (${Math.round(r.elapsed / 1000)}s)`
					).join("\n");

					return {
						content: [{ type: "text", text: `Chain "${chainName}" FAILED at step ${i + 1} (${step.agent})\n\n${summary}\n\nLast output:\n${result.output.slice(0, 4000)}` }],
						details: { chain: chainName, status: "error", steps: stepResults, totalElapsed },
					};
				}

				// Pass output to next step
				currentInput = result.output;
			}

			const summary = stepResults.map((r, idx) =>
				`  ${idx + 1}. ${r.agent}: ${r.status} (${Math.round(r.elapsed / 1000)}s)`
			).join("\n");

			// Auto-trigger self-improver if this is a storia chain and self-improver is in the team
			const isStoriaChain = chainName.startsWith("storia-");
			const hasSelfImprover = agentStates.has("self-improver");
			if (isStoriaChain && hasSelfImprover && !chainName.includes("evolve")) {
				// Don't await — fire and forget the self-improvement
				dispatchAgent("self-improver",
					`Retrospective on completed chain "${chainName}". Original goal: ${originalInput}\n\nStep results:\n${summary}`,
					ctx
				).catch(() => {});
			}

			return {
				content: [{ type: "text", text: `Chain "${chainName}" COMPLETE in ${Math.round(totalElapsed / 1000)}s\n\n${summary}\n\nFinal output:\n${currentInput.slice(0, 4000)}` }],
				details: { chain: chainName, status: "done", steps: stepResults, totalElapsed },
			};
		},

		renderCall(args, theme) {
			const chainName = (args as any).chain || "?";
			const input = (args as any).input || "";
			const preview = input.length > 50 ? input.slice(0, 47) + "..." : input;
			return new Text(
				theme.fg("toolTitle", theme.bold("dispatch_chain ")) +
				theme.fg("accent", chainName) +
				theme.fg("dim", " — ") +
				theme.fg("muted", preview),
				0, 0,
			);
		},

		renderResult(result, options, theme) {
			const details = result.details as any;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			if (options.isPartial || details.status === "running") {
				const step = details.step || "?";
				const agent = details.agent || "?";
				return new Text(
					theme.fg("accent", `● ${details.chain}`) +
					theme.fg("dim", ` step ${step}: ${agent}...`),
					0, 0,
				);
			}

			const icon = details.status === "done" ? "✓" : "✗";
			const color = details.status === "done" ? "success" : "error";
			const elapsed = typeof details.totalElapsed === "number" ? Math.round(details.totalElapsed / 1000) : 0;
			const stepCount = details.steps?.length || 0;
			const header = theme.fg(color, `${icon} ${details.chain}`) +
				theme.fg("dim", ` ${stepCount} steps · ${elapsed}s`);

			if (options.expanded && details.steps) {
				const lines = details.steps.map((s: any, i: number) => {
					const sIcon = s.status === "done" ? "✓" : "✗";
					const sColor = s.status === "done" ? "success" : "error";
					return theme.fg(sColor, `  ${sIcon} ${s.agent}`) +
						theme.fg("dim", ` ${Math.round(s.elapsed / 1000)}s`);
				}).join("\n");
				return new Text(header + "\n" + lines, 0, 0);
			}

			return new Text(header, 0, 0);
		},
	});

	// ── Commands ─────────────────────────────────

	pi.registerCommand("agents-team", {
		description: "Select a team to work with",
		handler: async (_args, ctx) => {
			widgetCtx = ctx;
			const teamNames = Object.keys(teams);
			if (teamNames.length === 0) {
				ctx.ui.notify("No teams defined in .pi/agents/teams.yaml", "warning");
				return;
			}

			const options = teamNames.map(name => {
				const members = teams[name].map(m => displayName(m));
				return `${name} — ${members.join(", ")}`;
			});

			const choice = await ctx.ui.select("Select Team", options);
			if (choice === undefined) return;

			const idx = options.indexOf(choice);
			const name = teamNames[idx];
			activateTeam(name);
			updateWidget();
			ctx.ui.setStatus("agent-team", `Team: ${name} (${agentStates.size})`);
			ctx.ui.notify(`Team: ${name} — ${Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ")}`, "info");
		},
	});

	pi.registerCommand("agents-list", {
		description: "List all loaded agents with tier and model info",
		handler: async (_args, _ctx) => {
			widgetCtx = _ctx;
			const grouped = agentsByTier();
			const lines: string[] = [];

			for (const [tier, agents] of grouped) {
				if (agents.length === 0) continue;
				lines.push(`\n${tierLabel(tier)}`);
				for (const s of agents) {
					const session = s.sessionFile ? "resumed" : "new";
					const expertise = loadExpertise(cwd, s.def.name) ? "★" : "○";
					lines.push(`  ${expertise} ${displayName(s.def.name)} [${s.currentModel}] (${s.status}, ${session}, runs: ${s.runCount}, fails: ${s.failCount})`);
					if (s.def.description) lines.push(`    ${s.def.description}`);
				}
			}

			_ctx.ui.notify(lines.join("\n") || "No agents loaded", "info");
		},
	});

	pi.registerCommand("agents-grid", {
		description: "Set grid columns: /agents-grid <1-6>",
		getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
			const items = ["1", "2", "3", "4", "5", "6"].map(n => ({
				value: n,
				label: `${n} columns`,
			}));
			const filtered = items.filter(i => i.value.startsWith(prefix));
			return filtered.length > 0 ? filtered : items;
		},
		handler: async (args, _ctx) => {
			widgetCtx = _ctx;
			const n = parseInt(args?.trim() || "", 10);
			if (n >= 1 && n <= 6) {
				gridCols = n;
				_ctx.ui.notify(`Grid set to ${gridCols} columns`, "info");
				updateWidget();
			} else {
				_ctx.ui.notify("Usage: /agents-grid <1-6>", "error");
			}
		},
	});

	pi.registerCommand("agents-metrics", {
		description: "Show evolution metrics",
		handler: async (_args, _ctx) => {
			widgetCtx = _ctx;
			const m = metrics;
			const lines = [
				`Evolution Cycle: #${m.evolution_cycle}`,
				`Tasks Completed: ${m.total_tasks_completed}`,
				`Worker Failures: ${m.total_worker_failures}`,
				`Lead Takeovers:  ${m.total_lead_takeovers}`,
				`Patterns Added:  ${m.total_patterns_added}`,
				`Patterns Pruned: ${m.total_patterns_pruned}`,
				`Prompt Changes:  ${m.total_prompt_changes}`,
			];

			const tokenEntries = Object.entries(m.expertise_tokens).filter(([, v]) => v > 0);
			if (tokenEntries.length > 0) {
				lines.push("", "Expertise Tokens:");
				for (const [agent, tokens] of tokenEntries) {
					lines.push(`  ${displayName(agent)}: ${tokens}`);
				}
			}

			_ctx.ui.notify(lines.join("\n"), "info");
		},
	});

	// ── System Prompt Override ───────────────────

	pi.on("before_agent_start", async (_event, _ctx) => {
		// Build dynamic agent catalog from active team, grouped by tier
		const grouped = agentsByTier();
		const catalogParts: string[] = [];

		for (const [tier, agents] of grouped) {
			if (agents.length === 0) continue;
			catalogParts.push(`### ${tierLabel(tier)}`);
			for (const s of agents) {
				const expertiseTag = loadExpertise(cwd, s.def.name) ? " ★expertise" : "";
				catalogParts.push(
					`**${displayName(s.def.name)}** (dispatch as: \`${s.def.name}\`, model: ${s.def.model}${expertiseTag})\n${s.def.description}\nTools: ${s.def.tools}`
				);
			}
		}

		const teamMembers = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");

		// Build chain catalog
		const chainCatalog = Object.entries(chains)
			.filter(([name]) => name.startsWith("storia-"))
			.map(([name, def]) => `- \`${name}\`: ${def.description} (${def.steps.length} steps: ${def.steps.map(s => s.agent).join(" → ")})`)
			.join("\n");

		return {
			systemPrompt: `You are a dispatcher agent for the storia-mobile agent harness. You coordinate specialist agents in a three-tier hierarchy: Orchestrator → Leads → Workers.

You do NOT have direct access to the codebase. You MUST delegate all work through agents using dispatch_agent or dispatch_chain.

## Active Team: ${activeTeamName}
Members: ${teamMembers}

## Tools Available

### dispatch_agent
Dispatch a single task to one agent. Automatically:
- Hotloads the agent's expertise file (.pi/expertise/) into its system prompt
- Uses the agent's assigned model (opus/sonnet/haiku per tier)
- Retries with model escalation on failure (haiku→sonnet→opus)
- Logs failures and metrics to .pi/evolution/

### dispatch_chain
Run a multi-step pipeline where each step's output feeds into the next.
Chains auto-trigger self-improvement after storia-* pipelines.

## How to Work
- Analyze the user's request and break it into clear sub-tasks
- Choose the right agent(s) for each sub-task based on their tier and domain
- For standard workflows, prefer dispatch_chain over manual multi-step dispatch
- For ad-hoc tasks, use dispatch_agent directly
- Review results and dispatch follow-up agents if needed
- If a task fails after model rotation, escalate to the user

## Three-Tier Hierarchy
- **Orchestrator**: Decomposes goals, delegates to leads. Never codes.
- **Leads**: Plan domain work, delegate to workers. Can code as fallback.
- **Workers**: Execute specific tasks. Specialists in one domain.
- **Validators**: Quick checks — tests, a11y, perf. Use haiku.
- **Meta**: Self-improver evolves the harness itself.

## Pipeline Chains

${chainCatalog || "No storia chains defined."}

## Agents

${catalogParts.join("\n\n")}`,
		};
	});

	// ── Session Start ────────────────────────────

	pi.on("session_start", async (_event, _ctx) => {
		applyExtensionDefaults(import.meta.url, _ctx);
		// Clear widgets from previous session
		if (widgetCtx) {
			widgetCtx.ui.setWidget("agent-team", undefined);
		}
		widgetCtx = _ctx;
		contextWindow = _ctx.model?.contextWindow || 0;

		// Wipe old agent session files so subagents start fresh
		const sessDir = join(_ctx.cwd, ".pi", "agent-sessions");
		if (existsSync(sessDir)) {
			for (const f of readdirSync(sessDir)) {
				if (f.endsWith(".json")) {
					try { unlinkSync(join(sessDir, f)); } catch {}
				}
			}
		}

		loadAgents(_ctx.cwd);

		// Default to first team — use /agents-team to switch
		const teamNames = Object.keys(teams);
		if (teamNames.length > 0) {
			activateTeam(teamNames[0]);
		}

		// Lock down to dispatcher-only tools
		pi.setActiveTools(["dispatch_agent", "dispatch_chain"]);

		_ctx.ui.setStatus("agent-team", `Team: ${activeTeamName} (${agentStates.size})`);
		const members = Array.from(agentStates.values()).map(s => displayName(s.def.name)).join(", ");
		_ctx.ui.notify(
			`Team: ${activeTeamName} (${members})\n` +
			`Chains: ${Object.keys(chains).filter(c => c.startsWith("storia-")).length} storia pipelines\n` +
			`Expertise: .pi/expertise/ hotloaded into agent prompts\n\n` +
			`/agents-team          Select a team\n` +
			`/agents-list          List agents with tier/model info\n` +
			`/agents-grid <1-6>    Set grid column count\n` +
			`/agents-metrics       Show evolution metrics`,
			"info",
		);
		updateWidget();

		// Footer: model | team | context bar
		_ctx.ui.setFooter((_tui, theme, _footerData) => ({
			dispose: () => {},
			invalidate() {},
			render(width: number): string[] {
				const model = _ctx.model?.id || "no-model";
				const usage = _ctx.getContextUsage();
				const pct = usage ? usage.percent : 0;
				const filled = Math.round(pct / 10);
				const bar = "#".repeat(filled) + "-".repeat(10 - filled);

				const tasksDone = metrics.total_tasks_completed;
				const fails = metrics.total_worker_failures;

				const left = theme.fg("dim", ` ${model}`) +
					theme.fg("muted", " · ") +
					theme.fg("accent", activeTeamName) +
					theme.fg("muted", " · ") +
					theme.fg("success", `${tasksDone}✓`) +
					(fails > 0 ? theme.fg("error", ` ${fails}✗`) : "");
				const right = theme.fg("dim", `[${bar}] ${Math.round(pct)}% `);
				const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));

				return [truncateToWidth(left + pad + right, width)];
			},
		}));
	});
}
