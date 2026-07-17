export type Forge = "github" | "gitlab";
export type ReferenceKind = "issue" | "merge-request";

export interface ForgeRepository {
	forge: Forge;
	host: string;
	path: string;
	selector: string;
}

export interface ForgeReference {
	kind: ReferenceKind;
	number: number;
	title: string;
	relatedIssues: number[];
}

export interface ReferenceToken {
	kind: ReferenceKind;
	marker: "#" | "!";
	query: string;
	prefix: string;
}

export interface ReferenceCompletionItem {
	value: string;
	label: string;
	description: string;
}

export interface ListCommand {
	command: "gh" | "glab";
	args: string[];
}

const MAX_REFERENCES = 100;
const MAX_RELATED_ISSUES = 5;

function classifyForge(host: string): Forge | undefined {
	if (host === "github.com" || /(^|\.)github\./.test(host)) return "github";
	if (host === "gitlab.com" || /(^|\.)gitlab\./.test(host) || host === "git.autodesk.com") {
		return "gitlab";
	}
	return undefined;
}

function parseRemoteLocation(remoteUrl: string): { host: string; path: string } | undefined {
	const trimmed = remoteUrl.trim();
	let host: string | undefined;
	let path: string | undefined;

	if (trimmed.includes("://")) {
		try {
			const parsed = new URL(trimmed);
			host = parsed.hostname.toLowerCase();
			path = parsed.pathname;
		} catch {
			return undefined;
		}
	} else {
		const match = /^(?:[^@/\s]+@)?([^:/\s]+):(.+)$/.exec(trimmed);
		if (!match) return undefined;
		host = match[1]?.toLowerCase();
		path = match[2];
	}

	const normalizedPath = path?.replace(/^\/+|\/+$/g, "").replace(/\.git$/, "");
	if (!host || !normalizedPath || !normalizedPath.includes("/")) return undefined;
	return { host, path: normalizedPath };
}

export function parseForgeRemote(remoteUrl: string): ForgeRepository | undefined {
	const location = parseRemoteLocation(remoteUrl);
	if (!location) return undefined;

	const forge = classifyForge(location.host);
	if (!forge) return undefined;

	const selector =
		forge === "github"
			? location.host === "github.com"
				? location.path
				: `${location.host}/${location.path}`
			: `https://${location.host}/${location.path}`;

	return { forge, ...location, selector };
}

export function findReferenceToken(
	lines: string[],
	cursorLine: number,
	cursorCol: number,
): ReferenceToken | undefined {
	const currentLine = lines[cursorLine] ?? "";
	const textBeforeCursor = currentLine.slice(0, cursorCol);
	const match = /(?:^|[\t ])([#!])([^\s#!]*)$/.exec(textBeforeCursor);
	if (!match) return undefined;

	const marker = match[1] as "#" | "!";
	const query = match[2] ?? "";
	return {
		kind: marker === "#" ? "issue" : "merge-request",
		marker,
		query,
		prefix: `${marker}${query}`,
	};
}

export function buildListCommand(repository: ForgeRepository, kind: ReferenceKind): ListCommand {
	if (repository.forge === "github") {
		const noun = kind === "issue" ? "issue" : "pr";
		const fields =
			kind === "issue" ? "number,title,state" : "number,title,state,body,closingIssuesReferences";
		return {
			command: "gh",
			args: [
				noun,
				"list",
				"--repo",
				repository.selector,
				"--state",
				"open",
				"--limit",
				String(MAX_REFERENCES),
				"--json",
				fields,
			],
		};
	}

	return {
		command: "glab",
		args: [
			kind === "issue" ? "issue" : "mr",
			"list",
			"--repo",
			repository.selector,
			"--per-page",
			String(MAX_REFERENCES),
			"--output",
			"json",
		],
	};
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asPositiveInteger(value: unknown): number | undefined {
	const number = typeof value === "string" && /^\d+$/.test(value) ? Number(value) : value;
	return typeof number === "number" && Number.isInteger(number) && number > 0 ? number : undefined;
}

function addIssueNumbers(target: Set<number>, value: unknown): void {
	if (!Array.isArray(value)) return;
	for (const item of value) {
		if (!isRecord(item)) continue;
		const number = asPositiveInteger(item.number ?? item.iid);
		if (number) target.add(number);
	}
}

export function extractIssueNumbers(text: string): number[] {
	const numbers = new Set<number>();
	for (const match of text.matchAll(/#(\d+)\b/g)) {
		const number = asPositiveInteger(match[1]);
		if (number) numbers.add(number);
	}
	for (const match of text.matchAll(/\/issues\/(\d+)\b/g)) {
		const number = asPositiveInteger(match[1]);
		if (number) numbers.add(number);
	}
	return [...numbers];
}

function unwrapList(value: unknown, kind: ReferenceKind): unknown[] {
	if (Array.isArray(value)) return value;
	if (!isRecord(value)) throw new Error("expected a JSON array");

	const candidates = kind === "issue" ? [value.issues, value.items] : [value.merge_requests, value.items];
	const list = candidates.find(Array.isArray);
	if (!list) throw new Error("expected a JSON array");
	return list;
}

export function parseReferenceList(stdout: string, kind: ReferenceKind): ForgeReference[] {
	const parsed = JSON.parse(stdout) as unknown;
	const references: ForgeReference[] = [];

	for (const value of unwrapList(parsed, kind)) {
		if (!isRecord(value)) continue;
		const number = asPositiveInteger(value.number ?? value.iid);
		const title = typeof value.title === "string" ? value.title.trim().replace(/\s+/g, " ") : "";
		if (!number || !title) continue;

		const relatedIssues = new Set<number>();
		if (kind === "merge-request") {
			addIssueNumbers(relatedIssues, value.closingIssuesReferences);
			const body =
				typeof value.body === "string"
					? value.body
					: typeof value.description === "string"
						? value.description
						: "";
			for (const issueNumber of extractIssueNumbers(body)) relatedIssues.add(issueNumber);
		}

		references.push({ kind, number, title, relatedIssues: [...relatedIssues] });
	}

	return references;
}

export function referenceSearchText(reference: ForgeReference): string {
	return `${reference.number} ${reference.title} ${reference.relatedIssues.map((number) => `#${number}`).join(" ")}`;
}

export function formatReferenceItem(
	reference: ForgeReference,
	forge: Forge,
): ReferenceCompletionItem {
	const marker = reference.kind === "issue" ? "#" : "!";
	const type = reference.kind === "issue" ? "issue" : forge === "github" ? "pr" : "mr";
	const related = reference.relatedIssues.slice(0, MAX_RELATED_ISSUES);
	const relationLabel = related.length > 0 ? ` · issues ${related.map((number) => `#${number}`).join(", ")}` : "";

	return {
		value: `${marker}${reference.number}`,
		label: `${marker}${reference.number}`,
		description: `[${type}${relationLabel}] ${reference.title}`,
	};
}
