# Zed

Modern code editor.

## Installation

```bash
brew install --cask zed
```

## Configuration

Configs: `~/.config/zed/` (symlinked via stow)

Includes:
- `settings.json` - Editor settings
- `keymap.json` - Keybindings

Note: Only config files are symlinked. Extensions directory stays local and won't pollute dotfiles.

## Setup

1. Launch Zed
2. Sign in to enable sync and collaboration features

Extensions will be managed locally in `~/.config/zed/extensions/`.

## Keybinding notes

### Debugging keymap conflicts

Zed keybindings are context-sensitive. A broad override such as `Workspace` can lose to a more-specific focused context like `ProjectSearchBar > Editor`, `!AcpThread > Editor && mode == full`, or a Vim mode context. When a keybinding does not fire:

1. Check Zed's upstream default keymap (`assets/keymaps/default-macos.json`).
2. Search for the key chord and the target action.
3. Add overrides for the specific focused contexts, not only `Workspace`.
4. Validate `keymap.json` as JSONC after edits.

Useful upstream contexts/actions found while tuning this config:

- Agent panel contexts: `AgentPanel`, `AcpThread`, `AcpThread > Editor`
- Editor/diff contexts: `Editor && mode == full`, `!AcpThread > Editor && mode == full`, `GitDiff > Editor`, `StashDiff > Editor`
- Search contexts: `BufferSearchBar`, `BufferSearchBar > Editor`, `BufferSearchBar && !in_replace > Editor`, `ProjectSearchBar`, `ProjectSearchBar > Editor`, `ProjectSearchBar && !in_replace > Editor`, `ProjectSearchView`
- Agent actions: `agent::ToggleFocus`, `agent::AddSelectionToThread`
- Focus/dock actions: `workspace::CloseActiveDock`, `workspace::FocusCenterPane`
- Search navigation actions: `search::SelectNextMatch`, `search::SelectPreviousMatch`

### Agent panel workflow

`cmd-shift-e` is Zed's default Project Panel shortcut in `Workspace`, and `pane::RevealInProjectPanel` in `!AcpThread > Editor && mode == full`. To make it reliably target Agent, override the regular editor, diff, project/sidebar, and Agent-specific contexts.

For a non-closing Agent focus swap, use:

- Editor → Agent: `agent::ToggleFocus`
- Agent → editor/center pane: `workspace::FocusCenterPane`
- Agent close/back-to-editor behavior: `workspace::CloseActiveDock`

`agent::AddSelectionToThread` opens/focuses Agent and inserts selected text, but it no-ops if there is no non-empty selection. Zed does not expose a reliable general keymap predicate for "has non-empty selection"; with Vim mode, `vim_mode == visual` is the practical selected-text proxy.

### Search navigation workflow

Zed defaults include:

- `cmd-g` → `search::SelectNextMatch`
- `cmd-shift-g` → `search::SelectPreviousMatch`

This config maps bracket keys to those actions. Vim/Zed defaults also bind:

- `ctrl-]` → `editor::GoToDefinition`
- `ctrl-[` → Vim escape/normal-mode switching

Those are intentionally overridden here because `g d` and `escape` cover those workflows.

