# Papercuts

Small frictions hit while working here — dead-end tool calls, broken links,
confusing setup steps, flaky commands, misleading errors, non-obvious gotchas.
Not blocking; logged so this repo can be sanded down. Distinct from tracked
bugs and from a work log.

Append with `papercut "<what got in the way>"`. Check off (`- [x]`) or delete
entries as they're fixed.

## Open

- [ ] 2026-07-11 — Debugging Neovim with temporary -u init files was easy to botch because mktemp paths without .lua are treated as Vimscript, producing misleading E480 errors from Lua code.
- [ ] 2026-07-11 — Editing an Obsidian Excalidraw canvas via 'obsidian eval': relied on app.workspace.activeLeaf.view, which silently pointed at a DIFFERENT open Excalidraw pane (a second .md), so all my probes/styles/test-writes ran against the wrong drawing and produced a baffling 112-vs-228 element-count discrepancy. Fix: resolve the target leaf by file.path (getLeavesOfType('excalidraw').find(l=>l.view.file.path===...)), never trust activeLeaf. · _opus-4.8_
- [ ] 2026-07-11 — ExcalidrawAutomate: addElementsToView() and deleteViewElements() require ea.setView(view) first. Without it they no-op — but the eval still returns success-looking data (before==mid==after), masking that nothing happened. The failure only showed up as a [error] log line I nearly missed. · _opus-4.8_
- [ ] 2026-07-11 — ExcalidrawAutomate ea.deleteViewElements(ids) did not actually delete (element count unchanged). Had to fall back to api.updateScene({elements: all.map(e=> kill.has(e.id)?{...e,isDeleted:true}:e)}) + await view.save(). That updateScene+isDeleted path is the reliable delete/undo. · _opus-4.8_
- [ ] 2026-07-11 — 'obsidian eval' does not support top-level await; a script with bare 'await' fails with no clear message (surfaces downstream as a JSON parse error). Must wrap the whole body in an async IIFE and 'return JSON.stringify(...)'. · _opus-4.8_
- [ ] 2026-07-11 — obsidian 'dev:screenshot' is viewport-only — no export-selected-elements. To capture a specific diagram region I had to setActiveLeaf + excalidrawAPI.scrollToContent(els,{fitToContent:true}) + force zoom, then screenshot. A one-shot 'export these element ids to png' would remove a lot of boilerplate. · _opus-4.8_
- [ ] 2026-07-12 — Two names for the same Obsidian CLI: /opt/homebrew/bin/obsidian (app-installed symlink) and obsidian-cli via .zprofile PATH append. Permission allow-rules in vault settings end up split across both spellings, so approvals don't accumulate. Pick one canonical name (obsidian) and drop the .zprofile PATH line. · _fable-5_
- [ ] 2026-07-12 — Editing claude/.claude/settings.json from a bg job dead-ended: worktree.baseRef=fresh branches from origin/main, but that file exists only on the mac branch (absent from main), so the isolation worktree lacked the file entirely — while the bg-edit guard blocked the shared checkout. Had to manually 'git worktree add -b … mac' and EnterWorktree by path. For mac-only files the fresh-from-main isolation is unusable. · _opus-4.8_
- [ ] 2026-07-12 — Repo-root .claude/settings.json is gitignored, so project-scoped Claude settings for the dotfiles repo itself can't be version-controlled. Had to write a dotfiles-drift skill override as an untracked local file instead of committing it. · _opus-4.8_
- [ ] 2026-07-16 — ctx_batch_execute's shell wrapper rejected a valid for-loop pipeline with 'parse error near for'; rerunning the audit as a direct rg command worked.
- [ ] 2026-07-16 — Pi's published package.json advertises a tsgo build script, but the installed production package contains no TypeScript compiler binary; extension type-check verification needs a separate compiler path.
- [ ] 2026-07-16 — GNU Stow 2.4.1 does not accept the intuitive --dry-run option; its simulation flag is -n/--no/--simulate.
- [ ] 2026-07-16 — macOS mktemp requires its X template at the end; '/tmp/name.XXXXXX.json' yielded an empty path and made 'tsc -p' report a misleading missing argument.
- [ ] 2026-07-16 — context-mode ctx_execute_file blocks Pi documentation and installed package files outside the workspace, despite those paths being required by the Pi task instructions; had to fall back to direct read.
- [ ] 2026-07-16 — context-mode could not read an invoked skill outside the project root, requiring a fallback to the read tool despite context-mode routing guidance
- [ ] 2026-07-16 — Direct web_search was unavailable because BRAVE_SEARCH_API_KEY is unset, even though delegated web-search-researcher agents can access current docs.
- [ ] 2026-07-16 — ctx_execute shell wrapper runs zsh semantics: assigning to status failed because status is readonly, after the expensive git clone had already completed.
- [ ] 2026-07-16 — context-mode ctx_execute_file cannot read Pi docs outside the project root, despite project instructions requiring those files; had to fall back to read.
- [ ] 2026-07-16 — PTY popup test sent input before Bash reached read, leaving bytes in canonical buffering and causing a false timeout; wait for the rendered prompt before writing input.
- [ ] 2026-07-16 — ctx_execute_file cannot read Pi's globally installed docs/examples outside the project root, despite those docs being required for Pi extension work; had to fall back to read.
- [ ] 2026-07-16 — launchctl bootstrap returned Input/output error after replacing the Headroom LaunchAgent plist with a Stow symlink; service state needed manual diagnosis.
- [ ] 2026-07-16 — Headroom 0.30 eagerly probes macOS Keychain fallback credentials even when GITHUB_COPILOT_GITHUB_TOKEN is explicitly set, causing an unexpected login-password dialog when the launchd proxy restarts.
- [ ] 2026-07-16 — ctx_batch_execute ran a valid-looking shell loop under a shell that reported 'parse error near for'; had to rerun the filesystem check separately.
- [ ] 2026-07-16 — Web search for current Headroom release failed because BRAVE_SEARCH_API_KEY is not configured; had to rely on local installed integration and GitHub alternatives.
- [ ] 2026-07-16 — A reachable git tree referenced a missing blob during local secret-history scanning; scanner needed to tolerate partial/missing objects.
- [ ] 2026-07-16 — ctx_execute_file blocked reading ~/.headroom launchd logs outside the project root during local service verification; had to fall back to a shell filter.
- [ ] 2026-07-16 — A ctx_execute source search failed because nested shell quoting around a ripgrep pattern was brittle; use an argument array or a simpler fixed pattern.
- [ ] 2026-07-16 — context-mode cannot read required Pi docs outside the project root; had to retry with direct read.
- [ ] 2026-07-16 — context-mode could not read globally installed skill files outside the project root; had to fall back to direct read.
- [ ] 2026-07-16 — context-mode cannot read Pi docs under /opt even though the project instructions require them; had to fall back to the read tool.
- [ ] 2026-07-16 — ctx_execute_file cannot read required skill/docs outside the project root, forcing fallback to read despite context-mode guidance.
- [ ] 2026-07-16 — settings.json changed between read and edit, so the exact replacement unexpectedly failed.
- [ ] 2026-07-16 — The requested apply_patch helper is unavailable in PATH; the edit tool also could not match text that read displayed verbatim, forcing a full-file write.
- [ ] 2026-07-16 — Pi RPC extension load check with --no-session still persisted the selected model into settings.json; use an ephemeral PI_CODING_AGENT_DIR for validation.
