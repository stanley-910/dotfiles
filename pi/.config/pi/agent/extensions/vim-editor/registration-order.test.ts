/**
 * Regression harness for the vim-editor editor-slot reclaim loop.
 *
 * Simulates Pi's extension runner: session_start handlers are awaited
 * sequentially in extension order, with vim-editor loading BEFORE rpiv-core,
 * whose chain awaits real I/O (git subprocesses) before its lane-switcher
 * handler installs LaneDockEditor via last-wins setEditorComponent — so the
 * clobber lands on the macrotask queue well after vim's handler returned.
 * Asserts vim installs immediately, reclaims the slot after both a
 * synchronous and an I/O-delayed clobber, and stands down on
 * session_shutdown.
 *
 * Run via ./run-tests.sh — index.ts imports @earendil-works packages by bare
 * specifier, which only resolve next to pi's installed package, so the runner
 * stages a temp copy with those deps symlinked in. Pi never loads this file
 * as an extension: subdirectory discovery loads index.ts/index.js only.
 */
import registerVimEditor from "./index.ts";

type Handler = (event: unknown, ctx: unknown) => unknown;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function makeFakePi() {
	const handlers = new Map<string, Handler[]>();
	return {
		pi: {
			on(event: string, handler: Handler) {
				const list = handlers.get(event) ?? [];
				list.push(handler);
				handlers.set(event, list);
			},
		},
		async fire(event: string, eventPayload: unknown, ctx: unknown) {
			for (const handler of handlers.get(event) ?? []) {
				await handler(eventPayload, ctx);
			}
		},
	};
}

function makeCtx() {
	let factory: unknown;
	return {
		ctx: {
			mode: "tui",
			ui: {
				setEditorComponent(f: unknown) {
					factory = f;
				},
				getEditorComponent() {
					return factory;
				},
			},
		},
		current: () => factory,
	};
}

async function waitFor(cond: () => boolean, timeoutMs: number): Promise<boolean> {
	const deadline = Date.now() + timeoutMs;
	while (Date.now() < deadline) {
		if (cond()) return true;
		await sleep(50);
	}
	return cond();
}

let failures = 0;
function assert(cond: boolean, label: string) {
	console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
	if (!cond) failures += 1;
}

const rivalUi = (ctx: unknown) => (ctx as { ui: { setEditorComponent(f: unknown): void } }).ui;

// --- Test 1: vim installs immediately; a synchronous rival clobber is reclaimed.
{
	const { pi, fire } = makeFakePi();
	registerVimEditor(pi as never);
	const rivalFactory = () => ({ rival: true });
	pi.on("session_start", async (_e, ctx) => {
		rivalUi(ctx).setEditorComponent(rivalFactory);
	});

	const { ctx, current } = makeCtx();
	const chain = fire("session_start", { type: "session_start", reason: "startup" }, ctx);
	assert(typeof current() === "function" && current() !== rivalFactory, "vim installs synchronously in its own handler");
	await chain;
	assert(
		await waitFor(() => current() !== rivalFactory && typeof current() === "function", 2000),
		"sync rival clobber: vim reclaims the editor",
	);
	await fire("session_shutdown", { type: "session_shutdown", reason: "quit" }, ctx);
}

// --- Test 2: rival installs only after awaited I/O (the real rpiv shape) — vim still reclaims.
{
	const { pi, fire } = makeFakePi();
	registerVimEditor(pi as never);
	const rivalFactory = () => ({ rival: true });
	pi.on("session_start", async (_e, _ctx) => {
		await sleep(250); // session-hooks awaits injectGitContext (subprocess I/O)
	});
	pi.on("session_start", async (_e, ctx) => {
		rivalUi(ctx).setEditorComponent(rivalFactory); // lane-switcher installs once per runtime
	});

	const { ctx, current } = makeCtx();
	await fire("session_start", { type: "session_start", reason: "startup" }, ctx);
	assert(current() === rivalFactory, "delayed rival owns the slot right after the chain (race reproduced)");
	assert(
		await waitFor(() => current() !== rivalFactory && typeof current() === "function", 2000),
		"delayed rival clobber: vim reclaims the editor",
	);
	await fire("session_shutdown", { type: "session_shutdown", reason: "quit" }, ctx);
}

// --- Test 3: shutdown stands the loop down — a rival installing afterwards is left alone.
{
	const { pi, fire } = makeFakePi();
	registerVimEditor(pi as never);
	const rivalFactory = () => ({ rival: true });

	const { ctx, current } = makeCtx();
	await fire("session_start", { type: "session_start", reason: "startup" }, ctx);
	await fire("session_shutdown", { type: "session_shutdown", reason: "reload" }, ctx);
	ctx.ui.setEditorComponent(rivalFactory);
	await sleep(400);
	assert(current() === rivalFactory, "after shutdown, vim no longer contests the slot");
}

// --- Test 4: reload (shutdown + new session_start) reclaims for the new ctx only.
{
	const { pi, fire } = makeFakePi();
	registerVimEditor(pi as never);
	const rivalFactory = () => ({ rival: true });
	pi.on("session_start", async (_e, ctx) => {
		rivalUi(ctx).setEditorComponent(rivalFactory);
	});

	const first = makeCtx();
	await fire("session_start", { type: "session_start", reason: "startup" }, first.ctx);
	await fire("session_shutdown", { type: "session_shutdown", reason: "reload" }, first.ctx);
	const staleFactory = first.current();
	const second = makeCtx();
	await fire("session_start", { type: "session_start", reason: "reload" }, second.ctx);
	assert(
		await waitFor(() => second.current() !== rivalFactory && typeof second.current() === "function", 2000),
		"new ctx got vim factory after reload",
	);
	assert(first.current() === staleFactory, "old ctx untouched after reload");
	await fire("session_shutdown", { type: "session_shutdown", reason: "quit" }, second.ctx);
}

// --- Test 5: non-tui mode never registers or schedules anything.
{
	const { pi, fire } = makeFakePi();
	registerVimEditor(pi as never);
	const { ctx, current } = makeCtx();
	(ctx as { mode: string }).mode = "print";
	await fire("session_start", { type: "session_start", reason: "startup" }, ctx);
	await sleep(300);
	assert(current() === undefined, "non-tui mode: no editor installed");
}

process.exit(failures === 0 ? 0 : 1);
