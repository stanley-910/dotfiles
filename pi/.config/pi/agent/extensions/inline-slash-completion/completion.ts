export interface SlashCommandToken {
	query: string;
	slashIndex: number;
}

export interface CompletionEdit {
	lines: string[];
	cursorLine: number;
	cursorCol: number;
}

const MAX_INLINE_SKILL_SUGGESTIONS = 15;

export function filterSkillCommands<T extends { value: string }>(items: T[]): T[] {
	return items
		.filter((item) => item.value.startsWith("skill:"))
		.slice(0, MAX_INLINE_SKILL_SUGGESTIONS);
}

export function findSlashCommandToken(
	lines: string[],
	cursorLine: number,
	cursorCol: number,
): SlashCommandToken | undefined {
	const currentLine = lines[cursorLine] ?? "";
	const textBeforeCursor = currentLine.slice(0, cursorCol);
	const match = /(?:^|[\t ])\/([^\s/]*)$/.exec(textBeforeCursor);
	if (!match) return undefined;

	const query = match[1] ?? "";
	return {
		query,
		slashIndex: textBeforeCursor.length - query.length - 1,
	};
}

export function isInlineSlashCommandToken(
	lines: string[],
	cursorLine: number,
	cursorCol: number,
): boolean {
	const token = findSlashCommandToken(lines, cursorLine, cursorCol);
	return token !== undefined && (cursorLine > 0 || token.slashIndex > 0);
}

export function shouldOpenInlineSlashPicker(
	lines: string[],
	cursorLine: number,
	cursorCol: number,
	input: string,
): boolean {
	if (input !== "/") return false;

	const currentLine = lines[cursorLine] ?? "";
	const beforeCursor = currentLine.slice(0, cursorCol);
	const atTokenBoundary = beforeCursor === "" || /[\t ]$/.test(beforeCursor);
	const builtInPickerWillOpen = cursorLine === 0 && beforeCursor.trim() === "";
	return atTokenBoundary && !builtInPickerWillOpen;
}

export function applyInlineSlashCompletion(
	lines: string[],
	cursorLine: number,
	cursorCol: number,
	value: string,
	prefix: string,
): CompletionEdit | undefined {
	if (/[\s/]/.test(prefix)) return undefined;

	const currentLine = lines[cursorLine] ?? "";
	const queryStart = cursorCol - prefix.length;
	const slashIndex = queryStart - 1;
	if (slashIndex < 0 || currentLine[slashIndex] !== "/") return undefined;
	if (slashIndex > 0 && !/[\t ]/.test(currentLine[slashIndex - 1] ?? "")) return undefined;
	if (cursorLine === 0 && slashIndex === 0) return undefined;

	const afterCursor = currentLine.slice(cursorCol);
	const suffix = afterCursor === "" || !/^[\t ]/.test(afterCursor) ? " " : "";
	const newLines = [...lines];
	newLines[cursorLine] = `${currentLine.slice(0, queryStart)}${value}${suffix}${afterCursor}`;

	return {
		lines: newLines,
		cursorLine,
		cursorCol: queryStart + value.length + suffix.length,
	};
}
