export interface FencedCodeBlock {
	language: string;
	text: string;
}

export interface CopyChoice {
	label: string;
	text: string;
}

interface OpeningFence {
	character: "`" | "~";
	length: number;
	language: string;
}

const WHOLE_MESSAGE_LABEL = "whole message";

function parseOpeningFence(line: string): OpeningFence | undefined {
	const match = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
	if (!match) return undefined;

	const marker = match[1];
	const info = match[2].trim();
	if (marker[0] === "`" && info.includes("`")) return undefined;

	return {
		character: marker[0] as "`" | "~",
		length: marker.length,
		language: info.split(/\s+/, 1)[0] ?? "",
	};
}

function isClosingFence(line: string, opening: OpeningFence): boolean {
	const match = line.match(/^ {0,3}(`+|~+)[\t ]*$/);
	if (!match) return false;

	const marker = match[1];
	return marker[0] === opening.character && marker.length >= opening.length;
}

export function extractFencedCodeBlocks(message: string): FencedCodeBlock[] {
	const lines = message.split(/\r?\n/);
	const blocks: FencedCodeBlock[] = [];

	for (let openingIndex = 0; openingIndex < lines.length; openingIndex++) {
		const opening = parseOpeningFence(lines[openingIndex]);
		if (!opening) continue;

		let closingIndex = openingIndex + 1;
		while (closingIndex < lines.length && !isClosingFence(lines[closingIndex], opening)) {
			closingIndex++;
		}

		if (closingIndex === lines.length) break;

		blocks.push({
			language: opening.language,
			text: lines.slice(openingIndex + 1, closingIndex).join("\n"),
		});
		openingIndex = closingIndex;
	}

	return blocks;
}

function uniqueLabel(base: string, usedLabels: Set<string>): string {
	let label = base;
	let occurrence = 2;

	while (usedLabels.has(label.toLowerCase())) {
		label = `${base} (${occurrence})`;
		occurrence++;
	}

	usedLabels.add(label.toLowerCase());
	return label;
}

export function buildCopyChoices(message: string): CopyChoice[] {
	const usedLabels = new Set([WHOLE_MESSAGE_LABEL]);
	const blockChoices = extractFencedCodeBlocks(message).map((block, index) => ({
		label: uniqueLabel(block.language || `code block ${index + 1}`, usedLabels),
		text: block.text,
	}));

	return [...blockChoices, { label: WHOLE_MESSAGE_LABEL, text: message }];
}
