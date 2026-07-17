import {
	copyToClipboard,
	type ExtensionAPI,
	type SessionEntry,
} from "@earendil-works/pi-coding-agent";
import { buildCopyChoices } from "./code-blocks.ts";

function getLastAssistantText(branch: SessionEntry[]): string | undefined {
	for (let index = branch.length - 1; index >= 0; index--) {
		const entry = branch[index];
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;

		const message = entry.message;
		if (message.stopReason === "aborted" && message.content.length === 0) continue;

		const text = message.content
			.filter((content): content is { type: "text"; text: string } => content.type === "text")
			.map((content) => content.text)
			.join("")
			.trim();
		return text || undefined;
	}

	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("y", {
		description: "Copy a code block or the whole last assistant message",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			await ctx.waitForIdle();
			const message = getLastAssistantText(ctx.sessionManager.getBranch());
			if (!message) {
				ctx.ui.notify("No assistant messages to copy yet", "error");
				return;
			}

			const choices = buildCopyChoices(message);
			const selectedLabel = await ctx.ui.select(
				"Copy from last assistant message",
				choices.map((choice) => choice.label),
			);
			if (!selectedLabel) return;

			const selected = choices.find((choice) => choice.label === selectedLabel);
			if (!selected) return;

			try {
				await copyToClipboard(selected.text);
				ctx.ui.notify(`Copied ${selected.label} to clipboard`, "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});
}
