/**
 * agent-link — /mr and /issue open the recorded MR/issue for this session
 * directly, no model turn (unlike prompt templates, which spend one).
 * Backed by ~/dotfiles/scripts/bin/agent-link; resolution is cwd-first, so
 * inside a worktree session it always opens that session's links.
 */
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const AGENT_LINK = join(homedir(), "dotfiles", "scripts", "bin", "agent-link");

export function agentLinkExecOptions(ctx: Pick<ExtensionCommandContext, "cwd">) {
	return { cwd: ctx.cwd };
}

export default function (pi: ExtensionAPI) {
	const register = (name: string, label: string) => {
		pi.registerCommand(name, {
			description: `Open the recorded ${label} for this session`,
			handler: async (_args: string, ctx) => {
				try {
					// ctx.cwd follows the active Pi session, unlike process.cwd() after
					// resuming from another checkout. Keep TMUX so agent-link can use the
					// validated pane pointer if the session cwd is unavailable.
					const result = await pi.exec(AGENT_LINK, ["open", name], agentLinkExecOptions(ctx));
					if (result.code !== 0) {
						throw new Error(result.stdout || result.stderr || `${label} lookup failed`);
					}
					ctx.ui.notify((result.stdout.trim() || `${label} opened`), "info");
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
