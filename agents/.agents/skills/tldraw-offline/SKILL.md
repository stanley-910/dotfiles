---
name: tldraw-offline
description: Operate the user's tldraw offline canvas app, including open .tldraw or .tldr files. Use whenever a task involves inspecting, editing, arranging, connecting, linting, or scripting a tldraw Desktop canvas.
---

# tldraw canvas operator

Use this skill for tasks involving open tldraw Desktop files. The desktop app exposes a local HTTP server that can list documents, inspect canvas state, capture screenshots, execute JavaScript against a live editor, and expose live script files for durable behavior.

## Server

The default server is `http://localhost:7236`. If that port is not active, read the `port` from `$HOME/Library/Application Support/tldraw/server.json`.

A clean quit removes `server.json`; the next launch rewrites it. It also records `pid` and `startedAt`, so if the file is present but requests to its `port` fail, treat it as stale (the app quit uncleanly) — the app is not running.

Every request except `GET /` and `/readme` needs the per-launch `token` from that same `server.json`, sent as `-H "authorization: Bearer <token>"`.

**If the server's base URL and bearer token are already in your context** — the app injects them at subagent launch when its agent hook is installed — use those literal values directly, or just call the installed `tq` helper (below). The rest of this section is the fallback for when neither is in hand.

**Each Bash tool call runs in a fresh shell — exported env vars do NOT persist between calls.** A `TLDRAW_TOKEN` you `export` in one call is empty in the next, so the request sends `authorization: Bearer` with no token and 401s. "Export once and reuse" does not work here — re-establish the port and token on every call. Read them together at the top of each call (both stay fixed for the app's lifetime, so re-reading is cheap):

```bash
PORT=$(jq -r .port "$HOME/Library/Application Support/tldraw/server.json"); TOKEN=$(jq -r .token "$HOME/Library/Application Support/tldraw/server.json")
# use as:  http://localhost:$PORT/...   -H "authorization: Bearer $TOKEN"
```

### Helper: `tq`

A ready-made helper ships with this skill at `"$HOME/.agents/skills/tldraw-offline/tq"`. Invoke it as `sh "$HOME/.agents/skills/tldraw-offline/tq" <METHOD> <path> [body]` — it re-reads the port and token from `server.json` itself on every call, so you never handle the token or the fresh-shell env problem. A body starting with `{` is sent as JSON; anything else as raw `text/plain`:

```bash
sh "$HOME/.agents/skills/tldraw-offline/tq" POST /api/search '{"code":"return await api.getDocs()"}'
sh "$HOME/.agents/skills/tldraw-offline/tq" POST /api/doc/DOC_ID/exec 'return editor.getCurrentPageShapes().length'
sh "$HOME/.agents/skills/tldraw-offline/tq" GET  /api/doc/DOC_ID/script-status
```

`tq` also normalizes percent-encoded colons in document IDs, working around tldraw Desktop 1.11.0's raw route matching. If `tq` is missing, fall back to raw `curl` with the `PORT`/`TOKEN` reads shown above and keep document IDs unencoded (`tldr:file:...`, not `tldr%3Afile%3A...`).

For a multi-file document-script change, stage the complete `script/` tree in a temporary directory and apply it with `tq-sync`. It uses rsync delayed updates so the app's 150 ms watcher debounce sees one coherent file set, then waits for `script-status.state === "applied"`:

```bash
sh "$HOME/.agents/skills/tldraw-offline/tq-sync" DOC_ID /path/to/staged-script
# Add --delete only when the staged directory is a complete replacement tree.
```

The raw-`curl` examples below remain explicit so each request is visible:

```bash
curl -s http://localhost:7236/readme
```

## Core endpoints

- `POST /api/search`: run JavaScript with an `api` object. Use this to discover docs, read shapes and bindings, capture screenshots, and query the editor API reference.
- `POST /api/doc/:id/exec`: run JavaScript with a live tldraw `editor` scoped to one document. Use this for saved canvas edits.
- `POST /api/doc/:id/script-workspace`: expose live script paths for direct durable document-script and asset edits.
- `GET /api/doc/:id/script-status`: inspect watcher state for `script/**` edits and find `errorLogPath`.

The code-taking POST endpoints accept raw JavaScript as the request body (`content-type: text/plain`) or a JSON body `{"code": "..."}`, and wrap the code in an async function so top-level `await` works. Prefer raw bodies for shell use. With raw `curl`, do not percent-encode the colon-bearing document ID in `/api/doc/:id/...`; use `tq` when a caller may encode it.

## Use this first

Most tasks do not require searching `api.members`. Start with these calls and search the full Editor API only if a snippet fails or you truly need an unknown method. The object is `api`, not `spec`. Each block below is shown as raw `curl` so the request is visible; `sh "$HOME/.agents/skills/tldraw-offline/tq" <METHOD> <path> [body]` is the shorter equivalent that handles the port and token for you.

```bash
# Fresh shell per call: re-read port + token first (or use the values already in your context).
PORT=$(jq -r .port "$HOME/Library/Application Support/tldraw/server.json"); TOKEN=$(jq -r .token "$HOME/Library/Application Support/tldraw/server.json")

# Pick the target doc by focused window or filename.
curl -s -X POST http://localhost:$PORT/api/search \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"return await api.getDocs({ name: \"NAME\" })"}'

# Read the current page's shapes with ids, bounds, text, and metadata.
curl -s -X POST http://localhost:$PORT/api/search \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"const doc = await api.getFocusedDoc(); const page = doc ? await api.getShapes(doc.id) : null; return { doc, shapes: page?.shapes.map(s => ({ id: s.id, type: s.type, x: s.x, y: s.y, props: s.props, meta: s.meta })) ?? [] }"}'

# Read bindings only for connection-dependent behavior.
curl -s -X POST http://localhost:$PORT/api/search \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"const doc = await api.getFocusedDoc(); return doc ? await api.getBindings(doc.id) : []"}'
```

## Reference recipes

`api.recipes` (via `/api/search`) is an object keyed by recipe `id`; read one in full with `api.recipes['<id>']`. Query it when a task matches one of the worked recipes:

- `stack-existing-boxes` — Stack existing boxes
- `add-durable-behavior-with-a-document-script` — Add durable behavior with a document script
- `editable-furniture-with-anchored-internals` — Editable furniture with anchored internals
- `clickable-card-or-button-ui` — Clickable card or button UI
- `connection-dependent-behavior` — Connection-dependent behavior
- `animation-simulation-loop` — Animation / simulation loop
- `custom-shape-config-js` — Custom shape (config.js)
- `custom-overlay-config-js` — Custom overlay (config.js)

Fetch `/readme` when an endpoint fails or you need API details not covered here.

## Durable UI Behavior

For durable UI behavior, open `/script-workspace`, read the existing `mainJsPath`, and preserve any non-default script. A one-file change may edit the live workspace directly. For two or more files, copy the current `scriptDir` into a temporary staging directory, edit the staged copy, then use `tq-sync` so imports and entrypoints arrive inside one watcher debounce window. Write dependencies before `config.js` or `main.js` if staging is impossible.

Check `script-status` once after the write. Treat `state: "applied"` as success; `"pending"` means retry once, and `"error"` means read `lastApplyError` / `errorLogPath`. Branch on `state` instead of re-deriving digest equality. The `/script-workspace` response reports `isDefaultScript`; when false, extend rather than clobber the preexisting script. Read the matching `api.recipes` entry before building clickable UI, animation, or custom shapes.

## Shape format

`api.getShapes()`, `/exec`, and document scripts all use raw tldraw SDK records. Create shapes with normal tldraw partials. Prefer importing primitives from `'tldraw'` when the host import map is active — in an `/exec` snippet use `await import('tldraw')` (a snippet can't use a static `import`); a document script can use a top-level `import { createShapeId } from 'tldraw'`. The `helpers` bag carries only editor-bound conveniences (not SDK primitives) — import primitives from `'tldraw'` directly.

`api.imports` is an array of module descriptors, not a flat symbol list. Each entry has `{ module, note, exports: [{ name, kind }] }`. Do not call `api.imports.includes(name)` and do not print the whole index. Query it narrowly:

```js
const wanted = new Set(['ShapeUtil', 'HTMLContainer', 'useValue'])
return api.imports.flatMap(({ module, exports }) =>
	(exports ?? []).filter(({ name }) => wanted.has(name)).map(({ name, kind }) => ({ module, name, kind }))
)
```

Then import confirmed primitives normally:

```js
const { createShapeId, toRichText } = await import('tldraw')
editor.createShape({
	id: createShapeId('box1'),
	type: 'geo',
	x: 100,
	y: 100,
	props: { geo: 'rectangle', w: 300, h: 200, richText: toRichText('Label') },
})
```

Use `api.getShapes(doc.id)` to inspect existing raw shape records before mutating them.

## Screenshots

`api.getScreenshot(docId, opts?)` captures a JPEG to a temp file and returns `{ filePath, width, height, pageName, viewport, bounds, captureMode }` — a path, not image data, so open the file yourself to look at it. `opts.size` is `'small' | 'medium' | 'large' | 'full'` (default `'small'`). `opts.mode` is `'canvas'` (default — just the shapes, framed to their bounds) or `'window'` (the whole app window: canvas plus UI chrome); use `'window'` to see UI a script's `components` override draws outside the canvas. `opts.bounds` (`{ x, y, w, h }` in page coordinates) applies to `'canvas'` mode only. Prefer reading records with `api.getShapes()`; screenshot only when visual placement is uncertain or the user asks for visual proof.

## Diagram connections

- Create every meaningful connection with `helpers.createArrowBetweenShapes(fromId, toId, options)` so both endpoints have real bindings.
- Never create a raw arrow shape for a meaningful connection. Raw unbound arrows are only appropriate for explicitly decorative marks.
- Run `helpers.getLints()` before reporting a diagram complete and address every actionable result. Fetch `/readme` for the helper recipe and the opt-out for intentional decorative arrows.

## Workflow

1. Restate the intended outcome in concrete canvas terms.
2. Choose durability:
   - Static drawing edits such as moving, arranging, labeling, or styling shapes use `/exec`.
   - Durable behavior such as clickable UI, animations, reactive layouts, or "run on open" logic uses `/script-workspace` and direct filesystem edits under `script/**`. Read the worked recipes from `api.recipes` (via `/api/search`) before building durable behavior.
3. Verify once with records from `api.getShapes()`, `api.getBindings()`, `api.getScriptStatus()`, or a screenshot when visual placement is uncertain.
4. Stop after one successful verification unless the user explicitly asks for debugging.

Never edit `.tldraw` archive files directly while they are open, and never edit `db.sqlite`, `db.sqlite-wal`, `db.sqlite-shm`, `metadata.json`, `.lock`, or `.script-workspace/**`.

## Durable script pattern: editable furniture, anchored internals

Use this when a document script draws a board that users should rearrange or restyle while script-owned animation/game pieces still follow it.

- Create user-facing furniture with stable ids and `helpers.createShapeIfMissing` / `helpers.createShapesIfMissing`; never delete and redraw it on rerun.
- Pick one visible anchor per interactive system, such as a track or table felt.
- Use `helpers.onShapeTranslate(anchorId, ({ dx, dy }) => ... , { signal })` to respond only to that anchor.
- Move script-owned internals with `helpers.translateShapes(..., dx, dy)` (it runs without recording undo history); wrap other script-owned writes in `editor.run(fn, { history: 'ignore' })`.
- Avoid broad `store.listen` / `afterChange` layout handlers that react to every shape; they can treat the script's own writes as new user edits and recurse.

## Editor customization: custom shapes, tools, and overlays (`config.js`)

Custom shape types, tools, overlays, or UI components need a `script/config.js` next to `main.js` (create it through `/script-workspace`, same as `main.js`) — a `main.js`-only script cannot register them. Its default export runs BEFORE the editor mounts, receives `{ config }` (the app's default `TldrawConfig`), and returns it after mutating or spreading it. The passed `config` carries `shapeUtils`, `bindingUtils`, `assetUtils`, `overlayUtils`, `tools` (arrays of constructors), `components` (a `TLComponents` map), and `options`; optional `getShapeVisibility(shape, editor)`, `assetUrls`, and `initialState`. Push your constructors onto the arrays — a util/tool whose static `type`/`id` matches a stock one replaces it. Custom shapes subclass `ShapeUtil` and custom overlays subclass `OverlayUtil` (both from `'tldraw'`); define them in a sibling file and `import` them, since `config.js` and `main.js` are separate module graphs.

Read `api.recipes['custom-shape-config-js']` or `api.recipes['custom-overlay-config-js']` for the full `ShapeUtil` / `OverlayUtil` skeleton before writing either. Saving `config.js` (or a file it imports) rebuilds the store and editor — document, camera, and selection are preserved but undo history resets — whereas saving `main.js` never remounts. Keep run-on-mount logic in `main.js`; `config.js` only builds the config. Types live in `.script-workspace/script-context.d.ts` (`ConfigScriptContext`, `TldrawConfig`).

### Interactive custom HTML shapes

- Make the `HTMLContainer` root `pointerEvents: 'none'` and give only the intended hit target `pointerEvents: 'all'`.
- Call `stopEventPropagation` and use pointer capture for drag interactions so tldraw selection/panning does not steal the gesture.
- Give interactive React children stable `key` values when a dynamic list appears before them; otherwise projection/filter changes can replace the hit target mid-drag and lose release events.
- Drive momentum or simulation with `editor.on('tick', frame)` and remove the listener in cleanup. Keep per-frame state in refs/local variables; persist shape metadata only when motion settles.

### Theme and canvas colors

Use `useValue('name', () => editor.user.getIsDarkMode(), [editor])` for a custom shape that reacts immediately to light/dark changes. The public theme API is discoverable through `api.members`: `editor.getCurrentTheme()`, `editor.updateTheme()`, and `editor.setCurrentTheme()`. To change the whole canvas, update both `theme.colors.dark.background` and `negativeSpace` (and the light equivalents); a document script must reapply custom theme definitions on open.

## Fast path for static edits

Shown as raw `curl`; `sh "$HOME/.agents/skills/tldraw-offline/tq" <METHOD> <path> [body]` is the shorter equivalent that handles the port and token for you.

```bash
# Fresh shell per call: re-read port + token (or use the values already in your context).
PORT=$(jq -r .port "$HOME/Library/Application Support/tldraw/server.json"); TOKEN=$(jq -r .token "$HOME/Library/Application Support/tldraw/server.json")

# Discover docs.
curl -s -X POST http://localhost:$PORT/api/search \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"return await api.getDocs()"}'

# Read shapes for a doc.
curl -s -X POST http://localhost:$PORT/api/search \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"const [doc] = await api.getDocs(); return await api.getShapes(doc.id)"}'

# Mutate with /exec, then verify once with api.getShapes().
curl -s -X POST http://localhost:$PORT/api/doc/DOC_ID/exec \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $TOKEN" \
  -d '{"code":"const { createShapeId, toRichText } = await import(\"tldraw\"); const id = createShapeId(\"r1\"); editor.createShape({ id, type: \"geo\", x: 100, y: 100, props: { geo: \"rectangle\", w: 200, h: 100, richText: toRichText(\"Hello\") } }); return { created: [id] }"}'
```

## Reporting

Keep summaries tight. Include the doc id/name, changed shape ids or script path, and the one verification result. If something fails, quote the server error, digest mismatch, or the relevant `.script-workspace/error.log` line.
