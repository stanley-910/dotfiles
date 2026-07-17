/**
 * Report ask_user_question overlays as blocked state to Herdr's managed Pi
 * integration. Tool lifecycle events provide the matching completion signal
 * that rpiv:ask-user:prompt does not expose.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ASK_USER_TOOL = "ask_user_question";
const DEFAULT_LABEL = "Waiting for answer";

type AskUserArgs = {
	questions?: Array<{ header?: string }>;
};

function blockedLabel(args: unknown): string {
	const header = (args as AskUserArgs)?.questions?.[0]?.header?.trim();
	return header ? `${DEFAULT_LABEL}: ${header}` : DEFAULT_LABEL;
}

export default function (pi: ExtensionAPI) {
	const blockedCalls = new Set<string>();

	pi.on("tool_execution_start", (event) => {
		if (event.toolName !== ASK_USER_TOOL || blockedCalls.has(event.toolCallId)) {
			return;
		}

		blockedCalls.add(event.toolCallId);
		pi.events.emit("herdr:blocked", {
			active: true,
			label: blockedLabel(event.args),
		});
	});

	pi.on("tool_execution_end", (event) => {
		if (event.toolName !== ASK_USER_TOOL || !blockedCalls.delete(event.toolCallId)) {
			return;
		}

		pi.events.emit("herdr:blocked", { active: false });
	});
}
