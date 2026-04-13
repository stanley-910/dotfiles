---
name: obsidian-css-debug
description: Diagnose and fix visual bugs in Obsidian (clipped tooltips, wrong z-order, wrong fonts, broken modals) by inspecting the live DOM via `obsidian eval`, finding which rule and which source is responsible, testing the fix in-process, then writing a scoped CSS snippet. Use when a user reports "X popup is clipped / behind / wrong font / overlaps Y" in Obsidian. Assumes the `obsidian:obsidian-cli` skill is available.
argument-hint: [visual bug description]
---

# Obsidian CSS debugging

Closed-loop workflow for fixing visual bugs in a running Obsidian app: inspect → identify source rule → test live → write a scoped snippet → verify. Assumes `obsidian` CLI is available (see `obsidian:obsidian-cli`).

## Snippet location

```
/Users/stanley/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes-v1/.obsidian/snippets/
```

File a new snippet per distinct root cause. Name descriptively (`harper-tooltip-unclip.css`, `tasknotes-autocomplete-above-suggester.css`). Add a header comment explaining the root cause, the offending rule, and why this fix works — future-you needs the context when Obsidian/plugin updates break assumptions.

## Why not just use DevTools

DevTools loses focus when the user clicks into it, which dismisses hover tooltips, autocomplete popups, and autosuggest dropdowns — the exact things you usually need to inspect. `obsidian eval` runs in the main window's context without stealing focus, so transient popups stay put.

## Core workflow

1. **Screenshot** the bug state: `obsidian dev:screenshot path=/tmp/bug.png` then `Read` the PNG.
2. **Locate the broken element** and walk its ancestry.
3. **Find which CSS rule** is causing the behavior, and from which stylesheet.
4. **Test the fix live** via an injected `<style>` tag with a known id, so you can remove it cleanly.
5. **Write the snippet**, enable it via `app.customCss.enabledSnippets.add()`, and verify with the same measurement you used to confirm the test fix.

## Eval recipes

All of these run via `obsidian eval code="..."`. Quote the JS with `"` and escape inner strings with `'` to avoid shell-quoting pain. `obsidian eval` prints the expression's value, so end with a plain expression (not `return`).

### Find visible elements matching a class

```js
const all = document.querySelectorAll('[class*=suggest]');
const vis = Array.from(all).filter(e => {
  const r = e.getBoundingClientRect();
  return r.width > 0 && r.height > 0 && getComputedStyle(e).display !== 'none';
});
JSON.stringify(vis.map(e => ({
  cls: e.className,
  z: getComputedStyle(e).zIndex,
  rect: {x: Math.round(e.getBoundingClientRect().x), y: Math.round(e.getBoundingClientRect().y), w: Math.round(e.getBoundingClientRect().width), h: Math.round(e.getBoundingClientRect().height)}
})))
```

### Walk the ancestor chain (stacking contexts, overflow traps)

```js
const el = document.querySelector('.cm-diagnostic');
let p = el, chain = [];
while (p && p !== document.body) {
  const cs = getComputedStyle(p);
  chain.push({tag: p.tagName, cls: (p.className || '').toString().slice(0, 80), z: cs.zIndex, pos: cs.position, overflow: cs.overflow, transform: cs.transform !== 'none' ? 'yes' : 'no', opacity: cs.opacity});
  p = p.parentElement;
}
JSON.stringify(chain, null, 2)
```

Any `position != static` + `z-index != auto` establishes a stacking context. So do `transform != none`, `opacity < 1`, `isolation: isolate`, `filter != none`, `will-change`, `contain: layout|paint|strict`. If the element mysteriously renders above/below something, one of these is usually the reason.

### Find all rules affecting a selector

Use this to discover WHO set a value and which stylesheet it came from.

```js
let rules = [];
for (const s of document.styleSheets) {
  try {
    for (const r of s.cssRules) {
      if (r.selectorText && r.selectorText.includes('suggestion-container') && r.style && r.style.zIndex) {
        rules.push({sel: r.selectorText, z: r.style.zIndex, href: s.href ? s.href.slice(-60) : 'inline'});
      }
    }
  } catch(e) {}
}
JSON.stringify(rules)
```

`href: 'inline'` means injected via a `<style>` tag — usually a plugin. To find which plugin, scan `<style>` text content for a distinctive class name from the same block:

```js
const styles = document.querySelectorAll('style');
const hits = [];
styles.forEach((s, i) => {
  if (s.textContent && s.textContent.includes('suggestion-container') && s.textContent.includes('100000')) {
    hits.push({i, snippet: s.textContent.split('suggestion-container')[1]?.slice(0, 200)});
  }
});
JSON.stringify(hits)
```

The snippet will contain nearby class names like `.qaFileSuggestionItem` (QuickAdd) or `.tasknotes-*` that identify the plugin.

### Search for rules containing a substring (fuzzy lookup)

```js
JSON.stringify(Array.from(document.styleSheets).flatMap(s => {
  try { return Array.from(s.cssRules).filter(r => r.cssText && r.cssText.includes('cm-diagnostic')).map(r => r.cssText.slice(0, 200)) }
  catch(e) { return [] }
}).slice(0, 20))
```

### Inspect a CSS variable on a given element

```js
JSON.stringify({
  headerHeight: getComputedStyle(document.body).getPropertyValue('--header-height'),
  modalHeaderHeight: getComputedStyle(document.querySelector('.mod-tasknotes')).getPropertyValue('--header-height')
})
```

### Test a fix live (reversible)

```js
const s = document.createElement('style');
s.id = 'css-debug-test';
s.textContent = '.cm-tooltip { overflow: visible !important; }';
document.head.appendChild(s);
'injected'
```

Remove:

```js
document.getElementById('css-debug-test')?.remove(); 'removed'
```

### Trigger a hover tooltip programmatically

Critical when the target is a CM hover tooltip (lint, spellcheck) — the user can't hold a hover AND also let you inspect. Dispatch synthetic mouse events onto the element at the hover coordinates.

```js
const cmEl = document.querySelector('.mod-tasknotes .cm-editor');
const line = cmEl.querySelector('.cm-line');
const rect = line.getBoundingClientRect();
const x = rect.left + 15;
const y = rect.top + rect.height / 2;
const target = document.elementFromPoint(x, y);
['mousemove', 'mouseover'].forEach(type =>
  target.dispatchEvent(new MouseEvent(type, { bubbles: true, clientX: x, clientY: y }))
);
'dispatched'
```

Then query `.cm-tooltip-hover` to measure / screenshot.

### Enable a snippet programmatically

```js
app.customCss.enabledSnippets.add('my-snippet-name');
app.customCss.requestLoadSnippets();
'enabled'
```

Call `requestLoadSnippets()` again after editing an enabled snippet to hot-reload without toggling.

## CSS cascade gotchas specific to Obsidian + CodeMirror

### CodeMirror 6 scope classes boost specificity

CM6 injects every theme rule prefixed with a generated scope class like `.ͼ1`. So a rule that looks like `.cm-diagnostic { ... }` in a plugin's source code actually lands in the cascade as `.ͼ1 .cm-diagnostic` — specificity `(0,2,0)`, not `(0,1,0)`.

**Implication:** a user snippet `.cm-diagnostic { max-height: none !important }` (specificity `(0,1,0)`) will LOSE to the CM6-emitted rule even though both are `!important`, because the CM6 rule has higher specificity. To win, match or exceed: `.cm-tooltip .cm-diagnostic`, `body .cm-diagnostic`, or similar.

Confirm specificity loss by reading `getComputedStyle(el).maxHeight` after your snippet loads — if it still shows the plugin's value, you lost.

### CodeMirror pins inline `height` on tooltips

`.cm-tooltip-hover` and `.cm-tooltip-autocomplete` frequently get an inline `height: Npx` set by CM6's positioning code after it measures content against available viewport space. In narrow editor contexts (e.g., a single-line input in a modal), this measurement comes out small (often ~47px) and subsequent content growth gets clipped.

Combined with any `overflow: hidden` on `.cm-tooltip`, the inner content gets cropped and you see only the top strip of the popup. Fix: `height: auto !important` + `overflow: visible !important` on the specific `.cm-tooltip-*` variant. Inline styles lose to `!important` stylesheet rules.

### Harper plugin's aggressive base theme

Harper's CodeMirror base theme (as of Apr 2026) ships two rules that break other CM tooltips:

```css
.cm-tooltip { overflow: hidden !important; z-index: var(--layer-menu) !important; ... }
.cm-diagnostic { max-height: calc(100% - var(--header-height)) !important; ... }
```

The `.cm-tooltip` rule applies to ALL CM6 tooltips (hover, autocomplete, lint, completionInfo) — not just Harper's. It clips TaskNotes autocomplete, inline suggestion popups, and anything else CM-based. The `.cm-diagnostic` max-height has a nonsensical dependency on `--header-height` (Obsidian's tab header metric). Both are worth reporting upstream.

User-side fix pattern in `harper-tooltip-unclip.css` in the vault.

### Obsidian z-index layers

Standard layer variables (approximate values):

| Variable | Value |
|---|---|
| `--layer-cover` | 5 |
| `--layer-sidedock` | 10 |
| `--layer-status-bar` | 15 |
| `--layer-popover` | 30 |
| `--layer-slides` | 45 |
| `--layer-modal` | 50 |
| `--layer-menu` | 65 |
| `--layer-notice` | 70 |
| `--layer-tooltip` | 90 |
| `--layer-dragged-item` | 100 |

Read the live value: `getComputedStyle(document.body).getPropertyValue('--layer-menu')`.

Plugins sometimes hard-code aggressive values (`z-index: 100000`) that blow past all standard layers. When that happens:
- Don't lower the plugin's value globally — you'll break other consumers of the same class (e.g. QuickAdd setting `100000` on `.suggestion-container` affects every `EditorSuggest`-based popup).
- Raise the competing element above the hard-coded ceiling instead, or scope the override with `:has()` to the specific plugin's content:
  ```css
  .suggestion-container:has(.various-complements__suggestion-item) { z-index: ... }
  ```

### `:has()` for body-mounted popups

CM6 tooltips and EditorSuggest popups mount to body (or a sibling host div), not inside the modal/editor they belong to. You can't scope a rule by walking up to `.mod-tasknotes` or `.modal-container` — the popup isn't a descendant.

Workarounds:
- `:has()` on the popup itself to match by its content: `.suggestion-container:has(.various-complements__suggestion-item)`.
- `body:has(.mod-tasknotes) .cm-tooltip-autocomplete { ... }` to conditionally apply while a particular modal is open — useful when you want different z-index behavior only inside specific modals.

## Writing the snippet

Once the fix is verified, save to the snippets folder with:

1. **A header comment** explaining the root cause, the offending rule (including plugin name), and why the fix works. Future-you needs this when plugin versions change.
2. **Scoped selectors** — don't cast a wider net than the bug needs. Prefer `.cm-tooltip.cm-tooltip-autocomplete` over `.cm-tooltip`, and `.suggestion-container:has(.foo)` over `.suggestion-container`.
3. **Matching or higher specificity than the offending rule** — remember CM6 scope classes.
4. `!important` when fighting another `!important`, omit otherwise.

Enable with:
```bash
obsidian eval code="app.customCss.enabledSnippets.add('snippet-name'); app.customCss.requestLoadSnippets(); 'ok'"
```

Verify with the same measurement that reproduced the bug (rect, computed style, z-index) — visual confirmation via screenshot is also fine but numeric verification catches subtle cases.

## Memory you should check before starting

- `feedback_sidebar_scoping.md` — sidebar-only rules must be scoped with `.mod-right-split` / `.mod-left-split`.
- `project_tasknotes_widget_spacing.md` — known prior TaskNotes/Minimal theme interaction fix; uses `--line-width` / `--max-width`, not `--file-line-width`.
- `feedback_mv_not_git_mv.md` — use `mv` not `git mv` in this vault.
