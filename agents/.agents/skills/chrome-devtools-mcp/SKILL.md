---
name: chrome-devtools-mcp
description: Use Chrome DevTools MCP safely by launching or attaching to a debuggable Chrome first, then inspecting DOM, screenshots, network, performance, and live pages through MCP. Use when the user mentions Chrome DevTools MCP, browser MCP, inspect DOM, screenshots/photos, live inspector changes, remote debugging, headless Chrome, or browser automation with MCP.
---

# Chrome DevTools MCP

## Non-negotiable preflight

Before calling any Chrome DevTools MCP tool, ensure Chrome is reachable at the MCP-configured endpoint, normally `http://127.0.0.1:9222`.

1. Check whether Chrome is already debuggable:
   ```bash
   curl -sf http://127.0.0.1:9222/json/version
   ```
2. If that fails, launch Chrome with remote debugging:
   ```bash
   /Users/stanwang/.agents/skills/chrome-devtools-mcp/scripts/launch-chrome-debug.sh
   ```
3. Only then connect/list/search MCP tools:
   ```js
   mcp({ connect: "chrome-devtools" })
   mcp({ server: "chrome-devtools" })
   mcp({ search: "screenshot", server: "chrome-devtools" })
   ```

If `chrome-devtools` is missing from `mcp({})`, Pi has not reloaded MCP config. Tell the user to restart/reload Pi.

## Launch modes

Default is a visible, isolated Chrome profile so the user can open DevTools, inspect live, edit styles, and watch agent actions:

```bash
/Users/stanwang/.agents/skills/chrome-devtools-mcp/scripts/launch-chrome-debug.sh
```

Headless mode is for CI or unattended screenshots only; do **not** use it when the user wants live inspector access:

```bash
HEADLESS=1 /Users/stanwang/.agents/skills/chrome-devtools-mcp/scripts/launch-chrome-debug.sh
```

Useful overrides:

```bash
PORT=9223 CHROME_DEBUG_PROFILE="$HOME/.chrome-devtools-mcp-store-madden" \
  /Users/stanwang/.agents/skills/chrome-devtools-mcp/scripts/launch-chrome-debug.sh
```

If changing the port, the MCP config must also use the matching `--browserUrl http://127.0.0.1:<port>`.

## Agent workflow

1. Launch/check Chrome first; never assume MCP can see a browser.
2. Navigate with MCP tools or ask the user to navigate manually in the visible Chrome.
3. Before every MCP call, decide whether the tool returns the whole page, all requests, a trace, or a screenshot. If yes, narrow the question first with selectors, filters, pagination, or an evaluated script.
4. Prefer DOM/accessibility/snapshot tools for structure; use screenshots for visual layout or when the DOM is insufficient.
5. Save screenshots, traces, large snapshots, and request/response bodies to files when available, then inspect only the relevant excerpt.
6. Keep the Chrome process open until the user is done; do not kill it unless asked.
7. If MCP fails to attach, re-check `/json/version`, then restart the debuggable Chrome profile.

## Context-budget rules

Chrome DevTools MCP tools can dump a full accessibility tree, network body, trace, or page snapshot into the conversation. Treat those calls as expensive. The goal is to return the smallest JSON answer that proves or disproves the current hypothesis.

Use this order of preference:

1. **Programmatic page query** with `chrome_devtools_evaluate_script` returning a narrow JSON object.
2. **Built-in filtered/paginated tools** such as `chrome_devtools_list_network_requests` with `resourceTypes` and `pageSize`.
3. **Artifact-to-file tools** using `filePath`, `requestFilePath`, or `responseFilePath`, followed by focused file inspection.
4. **Full snapshot/screenshot/trace inline output** only when the user needs broad visual/structural context.

Avoid returning whole-page strings or unbounded arrays from `evaluate_script`; cap lists and include selectors/counts instead of full DOM content.

### Prefer evaluated polling over noisy waits

`chrome_devtools_wait_for` is convenient, but it returns the latest page snapshot after the wait. On large pages that can flood context. Use it only when you also need the post-wait snapshot. For a simple assertion like “did text X appear?”, poll inside `chrome_devtools_evaluate_script` and return a small object:

```js
mcp({
  tool: "chrome_devtools_evaluate_script",
  args: JSON.stringify({
    function: `async () => {
      const deadline = Date.now() + 30_000;
      const wanted = ["HELLO!", "hello!"];
      const selector = ".header-category-sub-menu .major-display-name";

      while (Date.now() < deadline) {
        const matches = [...document.querySelectorAll(selector)]
          .map((el) => el.textContent?.trim())
          .filter(Boolean);

        const found = matches.find((text) => wanted.includes(text));
        if (found) return { found: true, selector, text: found, matches };
        await new Promise((resolve) => setTimeout(resolve, 250));
      }

      return { found: false, selector, matches: [] };
    }`
  })
})
```

If the selector is unknown, first run a bounded query that returns candidate elements, not the full snapshot:

```js
() => [...document.querySelectorAll("a,button,h1,h2,[role]")]
  .map((el) => ({
    tag: el.tagName.toLowerCase(),
    role: el.getAttribute("role"),
    text: el.textContent?.trim().replace(/\s+/g, " ").slice(0, 80),
    href: el.getAttribute("href")
  }))
  .filter((x) => /hello|madden cash|featured store/i.test(x.text ?? ""))
  .slice(0, 20)
```

### Tool-specific filtering habits

- `chrome_devtools_take_snapshot`: pass `filePath` for large pages; use inline snapshots only for small pages or when locating unknown elements.
- `chrome_devtools_wait_for`: use only when the returned page snapshot is useful; otherwise use evaluated polling.
- `chrome_devtools_list_network_requests`: always set `pageSize`; use `resourceTypes` when looking for fetch/XHR, images, scripts, etc.
- `chrome_devtools_get_network_request`: save large bodies with `requestFilePath` / `responseFilePath`; do not inline large payloads.
- Screenshots, heap snapshots, and performance traces: save to a file and report the path unless the user explicitly asks to inspect the artifact inline.

## Live inspector workflow

For user-in-the-loop debugging:

- Use visible mode, not `HEADLESS=1`.
- The user can open DevTools in the launched Chrome window (`Option+Command+I` on macOS) or inspect targets from another Chrome via `chrome://inspect`.
- Agents should pause after navigation/screenshot if the user wants to make manual style/DOM changes, then continue inspecting the modified live page.

## dev-browser alternative

`dev-browser` is a useful fallback or complement when MCP is unavailable or when persistent named pages/sandboxed agent scripts are preferable. Its relevant patterns are: launch/connect first, keep named pages alive, inspect with AI-friendly snapshots, and use screenshots as artifacts. Do not substitute it silently if the user explicitly asked for Chrome DevTools MCP.
