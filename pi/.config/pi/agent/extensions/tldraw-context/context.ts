import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type FetchLike = (
	input: string,
	init?: RequestInit,
) => Promise<{ ok: boolean; json(): Promise<unknown> }>;

type LoadOptions = {
	serverJsonPath?: string;
	fetchImpl?: FetchLike;
	timeoutMs?: number;
};

type ServerMetadata = {
	port?: unknown;
	token?: unknown;
};

const TLDRAW_TRIGGER = /(?:\btldraw(?:\s+desktop)?\b|\.tldr(?:aw)?\b|\/skill:tldraw-offline\b|\bopen canvas\b)/i;

export function shouldActivateTldrawContext(text: string): boolean {
	return TLDRAW_TRIGGER.test(text);
}

export function formatTldrawContext(baseUrl: string, token: string, docs: unknown[]): string {
	const lines = [
		`The tldraw Desktop canvas server is running at ${baseUrl}.`,
		`Send the header 'Authorization: Bearer ${token}' on every request except GET / and /readme.`,
		`Prefer sh "$HOME/.agents/skills/tldraw-offline/tq" so each call re-reads the current server metadata.`,
	];
	if (docs.length > 0) {
		lines.push(`Open tldraw canvases, most-recently-active first: ${JSON.stringify(docs)}`);
	}
	return lines.join("\n");
}

export async function loadTldrawContext(options: LoadOptions = {}): Promise<string | undefined> {
	const serverJsonPath = options.serverJsonPath
		?? join(homedir(), "Library", "Application Support", "tldraw", "server.json");
	let metadata: ServerMetadata;
	try {
		metadata = JSON.parse(await readFile(serverJsonPath, "utf8")) as ServerMetadata;
	} catch {
		return undefined;
	}

	if (!Number.isInteger(metadata.port) || typeof metadata.token !== "string" || metadata.token.length === 0) {
		return undefined;
	}

	const baseUrl = `http://localhost:${metadata.port}`;
	const fetchImpl = options.fetchImpl ?? fetch;
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), options.timeoutMs ?? 1200);
	let docs: unknown[] = [];
	try {
		const response = await fetchImpl(`${baseUrl}/api/search`, {
			method: "POST",
			headers: {
				"content-type": "text/plain",
				authorization: `Bearer ${metadata.token}`,
			},
			body: "return await api.getDocs()",
			signal: controller.signal,
		});
		if (response.ok) {
			const payload = await response.json() as { result?: unknown };
			if (Array.isArray(payload.result)) docs = payload.result;
		}
	} catch {
		// The server metadata can be stale after an unclean quit. Base context is
		// still useful only when the endpoint answers, so suppress it below.
		return undefined;
	} finally {
		clearTimeout(timeout);
	}

	return formatTldrawContext(baseUrl, metadata.token, docs);
}
