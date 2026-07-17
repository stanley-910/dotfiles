import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteProvider } from "@earendil-works/pi-tui";
import {
	applyInlineSlashCompletion,
	filterSkillCommands,
	findSlashCommandToken,
	isInlineSlashCommandToken,
} from "./completion.ts";

function createInlineSlashCompletionProvider(current: AutocompleteProvider): AutocompleteProvider {
	return {
		async getSuggestions(lines, cursorLine, cursorCol, options) {
			if (!isInlineSlashCommandToken(lines, cursorLine, cursorCol)) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			const token = findSlashCommandToken(lines, cursorLine, cursorCol)!;
			const commandInput = `/${token.query}`;
			const suggestions = await current.getSuggestions([commandInput], 0, commandInput.length, {
				...options,
				force: false,
			});

			const skillCommands = suggestions ? filterSkillCommands(suggestions.items) : [];
			if (skillCommands.length === 0) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			// Omitting the slash from the prefix keeps Enter from submitting the
			// entire prompt after accepting a command in the middle of a message.
			return {
				items: skillCommands,
				prefix: token.query,
			};
		},

		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			return (
				applyInlineSlashCompletion(lines, cursorLine, cursorCol, item.value, prefix) ??
				current.applyCompletion(lines, cursorLine, cursorCol, item, prefix)
			);
		},

		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			if (isInlineSlashCommandToken(lines, cursorLine, cursorCol)) return true;
			return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
		},
	};
}

export default function (pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.addAutocompleteProvider(createInlineSlashCompletionProvider);
	});
}
