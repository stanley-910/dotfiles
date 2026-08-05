import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
	formatTldrawContext,
	loadTldrawContext,
	shouldActivateTldrawContext,
	type FetchLike,
} from "./context.ts";

test("activates for tldraw tasks but not unrelated canvas APIs", () => {
	assert.equal(shouldActivateTldrawContext("edit test.tldraw"), true);
	assert.equal(shouldActivateTldrawContext("use /skill:tldraw-offline"), true);
	assert.equal(shouldActivateTldrawContext("inspect the open canvas"), true);
	assert.equal(shouldActivateTldrawContext("draw with the HTML canvas API"), false);
});

test("formats server and open-document context", () => {
	const context = formatTldrawContext("http://localhost:7236", "secret", [{ name: "demo" }]);
	assert.match(context, /localhost:7236/);
	assert.match(context, /Bearer secret/);
	assert.match(context, /"name":"demo"/);
	assert.match(context, /\.agents\/skills\/tldraw-offline\/tq/);
});

test("loads live context from portable server metadata", async () => {
	const dir = await mkdtemp(join(tmpdir(), "tldraw-context-"));
	const serverJsonPath = join(dir, "server.json");
	await writeFile(serverJsonPath, JSON.stringify({ port: 8123, token: "test-token" }));
	const fetchImpl: FetchLike = async (input, init) => {
		assert.equal(input, "http://localhost:8123/api/search");
		assert.equal((init?.headers as Record<string, string>).authorization, "Bearer test-token");
		return { ok: true, async json() { return { result: [{ id: "doc:1", name: "demo" }] }; } };
	};
	try {
		const context = await loadTldrawContext({ serverJsonPath, fetchImpl });
		assert.match(context ?? "", /doc:1/);
	} finally {
		await rm(dir, { recursive: true, force: true });
	}
});

test("returns no context for missing or malformed metadata", async () => {
	assert.equal(await loadTldrawContext({ serverJsonPath: "/missing/server.json" }), undefined);
	const dir = await mkdtemp(join(tmpdir(), "tldraw-context-"));
	const serverJsonPath = join(dir, "server.json");
	await writeFile(serverJsonPath, JSON.stringify({ port: "bad", token: "" }));
	try {
		assert.equal(await loadTldrawContext({ serverJsonPath }), undefined);
	} finally {
		await rm(dir, { recursive: true, force: true });
	}
});
