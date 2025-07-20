# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Terminal Multiplexer
# brew install tmux
# mkdir -p ~/.config/tmux
# git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Shell Enhancements
# brew install zsh-autosuggestions zsh-syntax-highlighting
# git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
# git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

# Fuzzy Finder and Extensions
# brew install fzf
# git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab

# Modern CLI Tools
# brew install eza    # 0.21.4
# brew install bat    # 0.25.0_1
# brew install lsd    # 1.1.5

# Classics 
# brew install tree
# brew install rg     # 14.1.1


# Development Tools
# brew install starship         # Cross-shell prompt 
# brew install thefuck         # Command correction
# brew install fastfetch       # System info display

# Node.js Setup (Optional)
# brew install node@20
# npm install -g npm@latest
# npm install -g yarn

# Python Setup (Optional)
# brew install python@3.11
# pip3 install --user pipx
# pipx ensurepath

# Neovim 
# brew install neovim

# Additional Language Support (Optional)
# brew install rust
# brew install go
# brew install opam      # OCaml package manager
# brew install rbenv     # Ruby version manager

# After Installation Steps:
# 1. Run 'compaudit' and fix any permissions issues
# 2. Install tmux plugins: Press prefix + I (capital i) in tmux
# 3. Reload shell: 'source ~/.zshrc'
# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================

# Uncomment to use the profiling module  
zmodload zsh/zprof # run with zprof 

# Initialize Homebrew environment (macOS package manager)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Enable autojump plugin for directory navigation
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

# Show hidden files in glob patterns (files starting with .)
setopt globdots

# Disable XON/XOFF flow control (allows Ctrl+S to work in other applications)
stty -ixon

# ==============================================================================
# COMPLETION SYSTEM
# ==============================================================================

# Optimized completion loading - only run once
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit  # Rebuild if dump is older than 24 hours
else
  compinit -C  # Skip security check for faster loading
fi

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
bindkey -M vicmd 'p' paste-from-clipboard # p: Paste from clipboard
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

# Change cursor shape based on vi mode
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'  # Block cursor for command mode
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || 
       [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'  # Beam cursor for insert mode
  fi
}
zle -N zle-keymap-select

# Initialize line editor in insert mode with beam cursor
zle-line-init() {
    zle -K viins
    echo -ne "\e[5 q"
}
zle -N zle-line-init

# Set beam cursor on startup and for each new prompt
echo -ne '\e[5 q'
preexec() { echo -ne '\e[5 q' ;}

# Load edit-command-line function
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

# Require multiple Ctrl+D presses to exit shell
set -o ignoreeof

# ==============================================================================
# PLUGIN CONFIGURATION
# ==============================================================================

# fzf-tab: Enhanced tab completion with fzf
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# fzf-tab configuration
zstyle ':fzf-tab:*' fzf-flags '--bind=alt-s:toggle+down'  # Alt+S: Multi-select
zstyle ':fzf-tab:*' switch-group '<' '>'                  # Switch groups with < >
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview '' # Disable preview for git checkout
zstyle ':fzf-tab:*' fzf-bindings \
    'ctrl-s:accept' \
    'ctrl-n:preview-down' \
    'ctrl-p:preview-up'
zstyle ':fzf-tab:*' accept-line 'ctrl-e'                    # Enter: Accept & Execute
zstyle ':fzf-tab:*' continuous-trigger 'ctrl-d'
zstyle ':fzf-tab:*' fzf-min-height 20                       # Minimum height for the preview window
zstyle ':fzf-tab:*' fzf-pad 4                               # Padding around the preview window
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' popup-min-size 80 20
zstyle ':fzf-tab:*' popup-border none

# Add -E flag to allow external keys
zstyle ':fzf-tab:*' popup-extra-args '-E'

# Preview configuration for different commands
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -T --icons --no-permissions --no-user --no-time --level=2 --color=always $realpath' # Display two directories deep
zstyle ':fzf-tab:complete:(vim|cat|less|nano|cp|mv):*' fzf-preview 'bat --style=plain --color=always --line-range :50 $realpath 2>/dev/null || cat $realpath 2>/dev/null || eza -1 --icons --no-permissions --no-user --no-time --no-filesize --color=always $realpath'
zstyle ':fzf-tab:complete:ta:*' fzf-preview 'tmux ls | grep -F "${word}:" | sed "s/^.*: //"' # substitute session name with empty replacement
zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'

# Other plugins
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

# zsh-autosuggestions configuration
bindkey '^S' autosuggest-accept  # Ctrl+S: Accept suggestion

# FZF Configuration
if command -v fd > /dev/null; then
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .DS_Store"
else
  export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*' -not -path '*/node_modules/*' -not -name '.DS_Store'"
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
# PATH CONFIGURATION
# ==============================================================================

# Node.js (Homebrew installation)
export PATH="/opt/homebrew/opt/node@20/bin:$PATH"

# Python (local installation)
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# User local binaries (pipx installations)
export PATH="$PATH:/Users/stanley/.local/bin"

# ==============================================================================
# ALIASES
# ==============================================================================

# File and directory operations
alias ls='lsd -la'        # List with icons and details
alias la='lsd -a'         # List all files with icons  
alias ll='lsd -al'        # List all with details and icons
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

# Quick navigation
alias cc='cd ~/Developer/'     # Navigate to development directory
alias c.="cd ~/.config/"       # Navigate to config directory
alias cs="cd ~/School/"        # Navigate to school directory
alias -- -=popd               # Use - as popd shortcut

# tmux aliases
alias tls="tmux ls"
alias td="tmux detach"
# System
alias fastfetch='fastfetch --color-keys "38;5;230" --color-output "38;5;230"'

# IDE aliases
alias c="open -a 'Cursor.app' ."
alias ws="open -a 'WebStorm.app' ."

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

# Enhanced cd function with directory stack
function cd() {
    if [ $# -eq 0 ]; then
        set "$HOME"
    elif [ "$1" = "-" ]; then
        shift
    fi
    pushd "$@" >/dev/null
}

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
preexec () {
  echo -n "\\e]133;A\\e\\" # this is what was recognized by tmux with ghostty
}

# ==============================================================================
# EXTERNAL TOOL INITIALIZATION
# ==============================================================================

# Starship prompt
eval "$(starship init zsh)"

# OCaml package manager (opam)
# [[ ! -r '/Users/stanley/.opam/opam-init/init.zsh' ]] || source '/Users/stanley/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null

# Node Version Manager (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# Ruby version manager (rbenv)
eval "$(rbenv init - --no-rehash zsh)"

# TheFuck command correction
eval $(thefuck --alias)

# Less filter for file previews
export LESSOPEN='|~/.config/scripts/.lessfilter %s'

# Remove fastfetch from startup and make it an alias
alias sysinfo='fastfetch'

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"


# Function to detect if we're running in an integrated terminal
function is_integrated_terminal() {
  local parent_process
  # Get the parent process name
  parent_process=$(ps -o comm= -p $PPID)
  
  # Check for common IDE terminal processes
  [[ "$parent_process" =~ "Cursor" ]] || \
  [[ "$parent_process" =~ "webstorm" ]]
}

if [[ -z $TMUX ]] && ! is_integrated_terminal; then
  # Get the most recently active detached session
  LAST_SESSION=$(tmux ls -F "#{session_activity} #{session_name}" 2>/dev/null | grep -v attached | sort -r | head -n1 | cut -d' ' -f2)
  if [[ -n $LAST_SESSION ]]; then
     exec tmux attach -d -t "$LAST_SESSION"
  else
     exec tmux
  fi
fi
