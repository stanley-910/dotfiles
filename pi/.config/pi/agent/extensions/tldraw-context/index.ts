import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadTldrawContext, shouldActivateTldrawContext } from "./context.ts";

const SKILL_NAME = "tldraw-offline";

export default function (pi: ExtensionAPI) {
	let activeForSession = false;

	pi.on("session_start", (_event, ctx) => {
		activeForSession = shouldActivateTldrawContext(JSON.stringify(ctx.sessionManager.getBranch()));
	});

	pi.on("before_agent_start", async (event) => {
		activeForSession ||= shouldActivateTldrawContext(event.prompt);
		if (!activeForSession) return;
		if (!event.systemPromptOptions.skills?.some((skill) => skill.name === SKILL_NAME)) return;

		const liveContext = await loadTldrawContext();
		if (!liveContext) return;

		// Keep the per-launch bearer token ephemeral: add it to this turn's system
		// prompt rather than persisting a custom session message.
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Live tldraw Desktop\n\n${liveContext}`,
		};
	});
}
