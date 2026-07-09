/**
 * agent-link — /mr and /issue open the recorded MR/issue for this session
 * directly, no model turn (unlike prompt templates, which spend one).
 * Backed by ~/dotfiles/scripts/bin/agent-link; resolution is cwd-first, so
 * inside a worktree session it always opens that session's links.
 */
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const execFileAsync = promisify(execFile);
const AGENT_LINK = join(homedir(), "dotfiles", "scripts", "bin", "agent-link");

// Mirror of the Claude Code PostToolUse hook: when a bash command created an
// MR/PR, record its URL. pi's cwd is pinned at session creation and agents
// `cd <worktree> && …` inside each command, so prefer that cd target as the
// recording location.
function registerAutorecord(pi: ExtensionAPI) {
	pi.on("tool_result", async (event: any, ctx: any) => {
		try {
			const toolName = event?.toolName ?? event?.tool_name ?? "";
			if (toolName !== "bash") return;
			const command: string = event?.input?.command ?? "";
			if (!/\bglab mr create\b|\bgh pr create\b/.test(command)) return;
			const text = (event?.content ?? [])
				.map((c: any) => (typeof c?.text === "string" ? c.text : ""))
				.join("\n");
			const m = text.match(/https?:\/\/[^\s"'\\]+\/(?:-\/)?(?:merge_requests|pull)\/\d+/);
			if (!m) return;
			let cwd = process.cwd();
			const cd = command.match(/^\s*cd\s+("([^"]+)"|'([^']+)'|([^\s;&]+))\s*(?:&&|;)/);
			const target = cd?.[2] ?? cd?.[3] ?? cd?.[4];
			if (target) {
				cwd = target.replace(/^~(?=\/|$)/, homedir());
			}
			await execFileAsync(AGENT_LINK, ["add", "mr", m[0]], {
				cwd,
				env: { ...process.env, TMUX: "" },
			});
			ctx?.ui?.notify?.(`agent-link: recorded MR ${m[0]}`, "info");
		} catch {
			// fail open — recording must never break the session
		}
	});
}

export default function (pi: ExtensionAPI) {
	registerAutorecord(pi);
	const register = (name: string, label: string) => {
		pi.registerCommand(name, {
			description: `Open the recorded ${label} for this session`,
			handler: async (_args: string, ctx) => {
				try {
					// Blank TMUX so agent-link resolves from cwd/scan (deterministic
					// in-session) and echoes feedback instead of using the status line.
					const { stdout } = await execFileAsync(AGENT_LINK, ["open", name], {
						env: { ...process.env, TMUX: "" },
					});
					ctx.ui.notify((stdout.trim() || `${label} opened`), "info");
				} catch (err: any) {
					const msg = (err?.stdout || err?.stderr || err?.message || `${label} lookup failed`)
						.toString()
						.trim();
					ctx.ui.notify(msg, "error");
				}
			},
		});
	};
	register("mr", "MR/PR");
	register("issue", "issue");
}
