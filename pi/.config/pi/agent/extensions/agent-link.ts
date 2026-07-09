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

export default function (pi: ExtensionAPI) {
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
