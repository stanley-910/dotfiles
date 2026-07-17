import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type AutocompleteProvider,
	fuzzyFilter,
} from "@earendil-works/pi-tui";
import {
	buildListCommand,
	findReferenceToken,
	formatReferenceItem,
	parseForgeRemote,
	parseReferenceList,
	referenceSearchText,
	type ForgeReference,
	type ForgeRepository,
	type ReferenceKind,
} from "./forge.ts";

const MAX_SUGGESTIONS = 20;
const COMMAND_TIMEOUT_MS = 8_000;

type ReferenceLoader = (kind: ReferenceKind) => Promise<ForgeReference[] | undefined>;

async function resolveRepository(
	pi: ExtensionAPI,
	cwd: string,
	signal: AbortSignal,
): Promise<ForgeRepository | undefined> {
	let remoteName = "origin";
	let result = await pi.exec("git", ["remote", "get-url", remoteName], {
		cwd,
		signal,
		timeout: 5_000,
	});

	if (result.code !== 0) {
		const remotes = await pi.exec("git", ["remote"], { cwd, signal, timeout: 5_000 });
		remoteName = remotes.stdout.split("\n").find(Boolean)?.trim() ?? "";
		if (remotes.code !== 0 || !remoteName) return undefined;
		result = await pi.exec("git", ["remote", "get-url", remoteName], {
			cwd,
			signal,
			timeout: 5_000,
		});
	}

	if (result.code !== 0) return undefined;
	return parseForgeRemote(result.stdout.trim());
}

function filterReferences(references: ForgeReference[], query: string): ForgeReference[] {
	if (!query.trim()) return references.slice(0, MAX_SUGGESTIONS);

	if (/^\d+$/.test(query)) {
		const numericMatches = references
			.filter((reference) => String(reference.number).startsWith(query))
			.slice(0, MAX_SUGGESTIONS);
		if (numericMatches.length > 0) return numericMatches;
	}

	return fuzzyFilter(references, query, referenceSearchText).slice(0, MAX_SUGGESTIONS);
}

function createReferenceLoader(
	pi: ExtensionAPI,
	repository: ForgeRepository,
	cwd: string,
	signal: AbortSignal,
	notify: (message: string) => void,
): ReferenceLoader {
	const cache = new Map<ReferenceKind, Promise<ForgeReference[] | undefined>>();
	const reportedErrors = new Set<ReferenceKind>();

	return (kind) => {
		const cached = cache.get(kind);
		if (cached) return cached;

		const command = buildListCommand(repository, kind);
		const promise = (async () => {
			const result = await pi.exec(command.command, command.args, {
				cwd,
				signal,
				timeout: COMMAND_TIMEOUT_MS,
			});
			if (result.code !== 0) {
				const details = result.stderr.trim() || result.stdout.trim() || `exit code ${result.code}`;
				throw new Error(details);
			}
			return parseReferenceList(result.stdout, kind);
		})().catch((error: unknown) => {
			if (!signal.aborted && !reportedErrors.has(kind)) {
				reportedErrors.add(kind);
				const label = kind === "issue" ? "issues" : repository.forge === "github" ? "PRs" : "MRs";
				const details = error instanceof Error ? error.message : String(error);
				notify(`forge-autocomplete: failed to load ${label}: ${details}`);
			}
			return undefined;
		});

		cache.set(kind, promise);
		return promise;
	};
}

function createForgeAutocompleteProvider(
	current: AutocompleteProvider,
	repository: ForgeRepository,
	loadReferences: ReferenceLoader,
): AutocompleteProvider {
	return {
		triggerCharacters: ["#", "!"],

		async getSuggestions(lines, cursorLine, cursorCol, options) {
			const token = findReferenceToken(lines, cursorLine, cursorCol);
			if (!token) return current.getSuggestions(lines, cursorLine, cursorCol, options);

			const references = await loadReferences(token.kind);
			if (options.signal.aborted || !references || references.length === 0) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			const matches = filterReferences(references, token.query);
			if (matches.length === 0) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			return {
				prefix: token.prefix,
				items: matches.map((reference) => formatReferenceItem(reference, repository.forge)),
			};
		},

		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
		},

		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			if (findReferenceToken(lines, cursorLine, cursorCol)) return true;
			return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
		},
	};
}

export default function (pi: ExtensionAPI): void {
	let sessionAbort: AbortController | undefined;

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		sessionAbort?.abort();
		sessionAbort = new AbortController();
		const { signal } = sessionAbort;
		const repository = await resolveRepository(pi, ctx.cwd, signal);
		if (!repository || signal.aborted) return;

		const loadReferences = createReferenceLoader(
			pi,
			repository,
			ctx.cwd,
			signal,
			(message) => ctx.ui.notify(message, "error"),
		);

		void loadReferences("issue");
		void loadReferences("merge-request");
		ctx.ui.addAutocompleteProvider((current) =>
			createForgeAutocompleteProvider(current, repository, loadReferences),
		);
	});

	pi.on("session_shutdown", () => {
		sessionAbort?.abort();
		sessionAbort = undefined;
	});
}
