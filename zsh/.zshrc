
# Show hidden files in glob patterns (files starting with .)
setopt globdots

# Disable XON/XOFF flow control (allows Ctrl+S to work in other applications)
[[ -t 0 ]] && stty -ixon

# ==============================================================================
# COMPLETION SYSTEM
# ==============================================================================

# completions
autoload -Uz compinit && compinit

# Include hidden files in completions
_comp_options+=(globdots)

# Completion styling and behavior
zstyle ':completion:*' menu select                    # Use menu selection
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # Enable filename colorizing
zstyle ':completion:*:descriptions' format '[%d]'     # Set descriptions format
zstyle ':completion:*' menu no                        # Disable default menu (for fzf-tab)
zstyle ':completion:*:git-checkout:*' sort false      # Disable sort for git checkout

# Case-insensitive completion with smart matching
zstyle ':completion:*' matcher-list \
    'm:{[:lower:]}={[:upper:]}' \
    '+r:|[._-]=* r:|=*' \
    '+l:|=*'

# Load completion list module
zmodload zsh/complist

# ==============================================================================
# VI MODE CONFIGURATION
# ==============================================================================

# Enable vi mode
bindkey -v
export KEYTIMEOUT=10

GLOBAL_WORDCHARS='*?_.[]~=&;!#$%^(){}<>:,"'"'"
# Custom word deletion functions
my-backward-kill-word () {
    local WORDCHARS=GLOBAL_WORDCHARS
    zle -f kill
    zle backward-kill-word
}
zle -N my-backward-kill-word

my-forward-kill-word () {
    local WORDCHARS=GLOBAL_WORDCHARS
    zle -f kill
    zle kill-word
}
zle -N my-forward-kill-word

# Custom yank function that copies to system clipboard
function vi-yank-xclip {
    zle vi-yank
    echo "$CUTBUFFER" | pbcopy -i
}
zle -N vi-yank-xclip

# ==============================================================================
# KEY BINDINGS
# ==============================================================================

function retry_command {
  BUFFER="fuck"
  CURSOR=$#BUFFER
  zle accept-line           # This simulates pressing Enter
}
zle -N retry_command

bindkey ' ' magic-space
# ?!string!
# !*
# !!
# retry failed command with most likely output
bindkey '^[r' retry_command

# Word manipulation
bindkey '^w' my-backward-kill-word    # Ctrl+W: Delete word backward
bindkey '^x' my-forward-kill-word     # Ctrl+X: Delete word forward
bindkey '\ed' my-forward-kill-word    # Alt+D: Delete word forward

# line nav
bindkey "^a" beginning-of-line
bindkey "^e" end-of-line

# Undo and clipboard
bindkey '^Z' undo                     # Ctrl+Z: Undo last action
bindkey '^y' yank                     # Ctrl+Y: Paste from kill ring

# Vi mode specific bindings
bindkey -M viins 'kj' vi-cmd-mode     # kj: Enter command mode from insert
bindkey -M vicmd 'y' vi-yank-xclip    # y: Yank to system clipboard
bindkey -M viins '^C' vi-cmd-mode     # Ctrl+C: Enter command mode
bindkey '^?' backward-delete-char     # Backspace: Delete character backward
bindkey '^v' edit-command-line        # Ctrl+V: Edit command in $EDITOR

# Menu selection navigation
bindkey -M menuselect '^[[Z' reverse-menu-complete  # Shift+Tab: Previous item

# History navigation with partial matching
autoload up-line-or-beginning-search
autoload down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^k' up-line-or-beginning-search
bindkey '^j' down-line-or-beginning-search

# Tmux sessionizer function and binding
function tmux_sessionizer() {
    BUFFER="~/.config/scripts/tmux-sessionizer"
    zle accept-line
}
zle -N tmux_sessionizer
bindkey ^f tmux_sessionizer

# ==============================================================================
# CURSOR CONFIGURATION
# ==============================================================================
if [[ -t 0 ]]; then
  zle-line-init() {
      zle -K viins
      echo -ne "\e[1 q"
  }
  zle -N zle-line-init
  echo -ne '\e[1 q'
  autoload -Uz add-zsh-hook
  _set_block_cursor() { echo -ne '\e[1 q' }
  add-zsh-hook preexec _set_block_cursor
fi

# Load vim edit-command-line function
autoload edit-command-line; zle -N edit-command-line

# ==============================================================================
# HISTORY CONFIGURATION
# ==============================================================================

# History settings
# setopt SHARE_HISTORY              # Share history between sessions (disabled for tmux)
setopt HIST_EXPIRE_DUPS_FIRST     # Expire duplicate entries first
HISTFILE=$HOME/.zhistory          # History file location
SAVEHIST=1000                     # Number of entries to save
HISTSIZE=999                      # Number of entries to keep in memory

# disable Ctrl+D to exit shell
set -o ignoreeof

# ==============================================================================
# PLUGIN CONFIGURATION
# ==============================================================================

# Ghostty shell integration. Ghostty only auto-injects this into the outermost
# zsh it spawns (via ZDOTDIR), so nested shells (inside tmux, exec zsh, sudo -E
# zsh) lose it. Re-source here so the precmd/preexec hooks — title updates
# on cd, OSC 133 prompt marks, cursor shape — run in every interactive shell.
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  autoload -Uz -- "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
  ghostty-integration
  unfunction ghostty-integration
fi

# fzf-tab: Enhanced tab completion with fzf
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# fzf-tab configuration
zstyle ':fzf-tab:*' switch-group '<' '>'                  # Switch groups with < >
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview '' # Disable preview for git checkout
zstyle ':fzf-tab:*' fzf-bindings \
    'ctrl-s:accept' \
    'ctrl-n:preview-down' \
    'ctrl-p:preview-up'
zstyle ':fzf-tab:*' accept-line 'ctrl-e'                    # Enter: Accept & Execute
zstyle ':fzf-tab:*' continuous-trigger 'ctrl-space'
zstyle ':fzf-tab:*' fzf-min-height 20                       # Minimum height for the preview window
zstyle ':fzf-tab:*' fzf-pad 4                               # Padding around the preview window
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' popup-min-size 80 20
zstyle ':fzf-tab:*' popup-border none

# Add -E flag to allow external keys
zstyle ':fzf-tab:*' popup-extra-args '-E'
# Disable preview by default and hide preview window
# individually add multiselect, since fzf-flags overrides 
zstyle ':fzf-tab:complete:*:*' fzf-preview ''
zstyle ':fzf-tab:complete:*:*' fzf-flags '--bind=alt-s:toggle+down' '--preview-window=hidden'
# Only show preview window for specific commands with useful content
# Preview configuration for different commands
zstyle ':fzf-tab:complete:(cd|z):*' fzf-flags '--bind=alt-s:toggle+down' '--preview-window=right:50%'
zstyle ':fzf-tab:complete:(cd|z):*' fzf-preview 'eza -T --all --git-ignore --icons --no-permissions --no-user --no-time --level=2 --color=always $realpath' # Display two directories deep
zstyle ':fzf-tab:complete:(vim|cat|less|nano|cp|mv):*' fzf-flags '--bind=alt-s:toggle+down' '--preview-window=right:50%'
zstyle ':fzf-tab:complete:(vim|cat|less|nano|cp|mv):*' fzf-preview 'bat --style=plain --color=always --line-range :50 $realpath 2>/dev/null || cat $realpath 2>/dev/null || eza -1 --icons --no-permissions --no-user --no-time --no-filesize --color=always $realpath'
zstyle ':fzf-tab:complete:ta:*' fzf-flags '--bind=alt-s:toggle+down' '--preview-window=right:50%'
zstyle ':fzf-tab:complete:ta:*' fzf-preview 'tmux ls | grep -F "${word}:" | sed "s/^.*: //"' # substitute session name with empty replacement

# Other plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting configuration (styles and patterns must be set BEFORE sourcing)
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#6fa37a,bold' #  green
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#81a1c1,bold' # light blue
ZSH_HIGHLIGHT_STYLES[function]='fg=#b48ead'     # also light blue kinda
ZSH_HIGHLIGHT_STYLES[alias]='fg=#b48ead'        # purple
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#bf616a,bold' #red
ZSH_HIGHLIGHT_STYLES[path]='none' # disable path underlining
ZSH_HIGHLIGHT_STYLES[precommand]='fg=green' # disable command modifier underlining (sudo, builtin)

typeset -A ZSH_HIGHLIGHT_PATTERNS
ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=white,bold,bg=red')

source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

# zsh-autosuggestions configuration
bindkey '^S' autosuggest-accept  # Ctrl+S: Accept suggestion

# FZF Configuration
if command -v fd > /dev/null; then
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .venv --exclude .DS_Store"
else
  export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*' -not -path '*/node_modules/*' -not -path '*/\.venv/*' -not -name '.DS_Store'"
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Basic FZF options without preview
export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--multi
--bind 'ctrl-a:select-all'
--bind 'ctrl-s:accept'
--bind 'ctrl-y:execute-silent(echo {+} | pbcopy)'
--bind 'ctrl-e:execute(echo {+} | xargs -o nvim)'
--bind 'ctrl-v:execute(code {+})'
--bind ctrl-d:down,ctrl-q:up
"

# File-specific preview configuration
export FZF_CTRL_T_OPTS="
--preview-window=:hidden
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--bind '?:toggle-preview'
"

# ALT-C directory preview
export FZF_ALT_C_OPTS="
--preview 'tree -C {} | head -200'
--bind '?:toggle-preview'
"

# ==============================================================================
# ALIASES
# ==============================================================================

# File and directory operations
alias ls='eza -la --icons'                    # List with icons, details and git status (including hidden files)
alias la='eza -la --icons --git --total-size'                     # List with icons and details (no hidden files)
alias ll='eza -la --icons --git'       # List all with details, icons, git status and directory sizes
alias v="nvim"            # Quick nvim access
alias vim="nvim"          # Use neovim instead of vim
alias t="tmux"            # Quick tmux access

# Git shortcuts
alias ga='git add'
alias gs='git status'
alias gp='git push'
alias gP='git pull'
alias gb='git branch'
alias gch='git checkout'
alias gr='git remote'
alias gg='cd "$(git rev-parse --show-toplevel)"'

alias -- -=popd               # Use - as popd shortcut

# tmux aliases
alias tls="tmux ls"
alias td="tmux detach"
# System
alias fastfetch='fastfetch --color-keys "38;5;230" --color-output "38;5;230"'

# IDE aliases
alias c="open -a 'Cursor.app' ."
alias ws="open -a 'WebStorm.app' ."

# Claude Code — model tiers (update these when new flagships drop)
CLAUDE_MODEL_LOW="haiku"
CLAUDE_MODEL_MID="sonnet"
CLAUDE_MODEL_HIGH="opus"

# Usage: chud [-n] [-l|-m|-h|-x|-a]    (haiku)
#        cs   [-n] [-l|-m|-h|-x|-a]    (sonnet)
#        co   [-n] [-l|-m|-h|-x|-a]    (opus)
# -n = no thinking, -l/-m/-h/-x/-a = low/medium/high/max/auto effort
# chain freely: cs -nh = sonnet, no thinking, high effort
_cc() {
  local model=$1; shift
  local flags=()
  local no_think=0
  local effort=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -*) for (( i=1; i<${#1}; i++ )); do
            case ${1:$i:1} in
              n) no_think=1 ;;
              l) effort="low" ;;
              m) effort="medium" ;;
              h) effort="high" ;;
              x) effort="high" ;;
              a) effort="auto" ;;
            esac
          done ;;
    esac; shift
  done
  [[ -n "$effort" ]] && flags+=(--effort "$effort")
  if (( no_think )); then
    CLAUDE_CODE_DISABLE_THINKING=1 claude --model "$model" "${flags[@]}"
  else
    claude --model "$model" "${flags[@]}"
  fi
}

chud() { _cc "$CLAUDE_MODEL_LOW" "$@"; }
cs()   { _cc "$CLAUDE_MODEL_MID" "$@"; }
co()   { _cc "$CLAUDE_MODEL_HIGH" "$@"; }

# Global aliases
# Redirect stderr to /dev/null
alias -g NE='2>/dev/null'

# Redirect stdout to /dev/null
alias -g NO='>/dev/null'

# Redirect both stdout and stderr to /dev/null
alias -g NUL='>/dev/null 2>&1'

# Pipe to jq
alias -g J='| jq'

# Copy output to clipboard (macOS)
alias -g C='| pbcopy'

# Copy output to clipboard (Linux with xclip)
# alias -g C='| xclip -selection clipboard'

# ==============================================================================
# CUSTOM FUNCTIONS
# ==============================================================================

# Git functions
gc() {
  git commit -m "$*"
}

gac() {
  git add -A && git commit -m "$*" 
}

gasp() {
  git add -A && git commit -m "$*" && git push
}

# cd = zoxide + directory stack (so popd / - still works)
# function cd() {
#     if [[ $# -eq 0 ]]; then
#         pushd "$HOME" >/dev/null
#     elif [[ "$1" == "-" ]]; then
#         popd >/dev/null
#     else
#         pushd "$(zoxide query -- "$@" 2>/dev/null || echo "$1")" >/dev/null
#     fi
# }
#
# TMUX functions

# Kill all tmux sessions
tkill() {
    echo "Active sessions:"
    tmux ls
    echo "\nAre you sure you want to kill all sessions? (y/n) "
    read -k 1 answer
    echo # New line after response
    if [[ $answer =~ ^[Yy]$ ]]; then
        if [ -n "$TMUX" ]; then
            tmux switch-client -t $(tmux list-sessions -F "#{session_name}" | head -n 1)
        fi
        tmux kill-session -a
        tmux kill-session
        echo "All sessions killed."
    else
        echo "Operation cancelled."
    fi
}

ta() {
  # If -n flag is provided, allow nesting
  if [ "$1" = "-n" ]; then
    shift
    if [ $# -eq 0 ]; then
      tmux new-session
    else
      tmux new-session -s "$1"
    fi
    return
  fi

  # Get session name if provided
  local session_name="$1"

  # If no session name provided and not in tmux, just attach to any or create new
  if [[ -z "$session_name" ]] && [[ -z "$TMUX" ]]; then
    tmux attach || tmux new-session
    return
  fi

  # If no session name provided but in tmux, create random one
  if [[ -z "$session_name" ]]; then
    session_name="session-$(date +%s)"
  fi

  # Create session in detached state if it doesn't exist
  if ! tmux has-session -t="$session_name" 2> /dev/null; then
    tmux new-session -ds "$session_name"
  fi

  # If we're in a tmux session, switch to the new one
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session_name"
  else
    # If we're not in tmux, just attach to the session
    tmux attach -t "$session_name"
  fi
}

# Tmux session completion
_ta() {
    local sessions
    sessions=(${(f)"$(tmux ls 2>/dev/null | cut -d: -f1)"})
    _arguments '1:session:($sessions)' && return 0 # only allow one session to attach onto
}
compdef _ta ta

# echo OSC 133 escape sequence so tmux can navigate between prompts
# https://tanutaran.medium.com/tmux-jump-between-prompt-output-with-osc-133-shell-integration-standard-84241b2defb5
autoload -Uz add-zsh-hook
_osc133_preexec() { print -n "\e]133;A\e\\" }
add-zsh-hook preexec _osc133_preexec

# zmv - batch rename/move
# Enable zmv
autoload -Uz zmv

# Usage examples:
# zmv '(*).log' '$1.txt'           # Rename .log to .txt
# zmv -w '*.log' '*.txt'           # Same thing, simpler syntax
# zmv -n '(*).log' '$1.txt'        # Dry run (preview changes)
# zmv -i '(*).log' '$1.txt'        # Interactive mode (confirm each)

# Hook that runs when changing into a directory 
# chpwd() {
#   ls
# }

autoload -Uz add-zsh-hook
function auto_venv() {
  # If already in a virtualenv, do nothing
  if [[ -n "$VIRTUAL_ENV" && "$PWD" != *"${VIRTUAL_ENV:h}"* ]]; then
    deactivate
    return  
  fi

  [[ -n "$VIRTUAL_ENV" ]] && return

  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.venv/bin/activate" ]]; then
      source "$dir/.venv/bin/activate"
      return
    fi
    dir="${dir:h}"
  done
}
# add-zsh-hook chpwd auto_venv

# ==============================================================================
# EXTERNAL TOOL INITIALIZATION
# ==============================================================================

# Starship prompt
# Check that the function `starship_zle-keymap-select()` is defined to fix vim mode enable.
# xref: https://github.com/starship/starship/issues/3418
if [[ "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select" || \
      "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select-wrapped" ]]; then
    zle -N zle-keymap-select "";
fi

eval "$(starship init zsh)"

# Node Version Manager (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# TheFuck command correction
eval $(thefuck --alias)

# Less filter for file previews
export LESSOPEN='|~/.config/scripts/.lessfilter %s'

# Remove fastfetch from startup and make it an alias
alias sysinfo='fastfetch'

# Tmux auto-attach: attach to last detached session or create new
# if [[ -o interactive ]] && [[ -t 0 ]] && [[ -z $TMUX ]] && \
#    [[ "$TERM_PROGRAM" != "vscode" ]] && \
#    [[ "$TERM_PROGRAM" != "zed" ]] && \
#    [[ "$OPENCODE" != 1 ]] && \
#    [[ "$TERMINAL_EMULATOR" != "JetBrains-JediTerm" ]]; then
#   LAST_SESSION=$(tmux ls -F "#{session_activity} #{session_name}" 2>/dev/null | grep -v attached | sort -r | head -n1 | cut -d' ' -f2)
#   if [[ -n $LAST_SESSION ]]; then
#      exec tmux attach -d -t "$LAST_SESSION"
#   else
#      exec tmux
#   fi
# fi
#
# yazi function
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# Wrapper for mkdir that adds 'cd' to history for autosuggestions
# After creating a directory, the next command suggestion will be 'cd <dirname>'
mkdir() {
    # Run the actual mkdir command with all provided arguments
    command mkdir "$@"
    local exit_code=$?
    
    # If mkdir succeeded (exit code 0) and we have arguments
    if [[ $exit_code -eq 0 && $# -gt 0 ]]; then
        # Get the last argument (the directory name)
        local dir="${@: -1}"
        
        # Add 'cd' command to history so it appears in autosuggestions
        # The history entry is timestamped with current time
        print -s "cd $dir"
    fi
    
    return $exit_code
}

mkf() {
    mkdir -p "$(dirname "$1")" && touch "$1"
}

eval "$(zoxide init zsh --no-cmd)"
alias z='__zoxide_z'
alias zi='__zoxide_zi'

# use nvim as man page reader
export MANPAGER='nvim +Man!'

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Python is managed by uv (uv run / uv venv; per-project .python-version is
# honored automatically). Default python/python3 shims live in ~/.local/bin via
# `uv python install --default`, and ~/.local/bin is on PATH from .zshenv —
# so there is nothing Python-related to export here. No pyenv.
