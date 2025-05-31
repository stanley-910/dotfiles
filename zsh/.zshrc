# =============================================================================
#                              ZSH Configuration
# =============================================================================
# Dependencies Required:
# 1. Homebrew packages:
#    - brew install starship node@20 python autojump thefuck lsd fastfetch fzf
#
# 2. ZSH Plugins (clone these into ~/.zsh/):
#    - git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
#    - git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
#    - git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
#    - git clone https://github.com/marlonrichert/zsh-autocomplete ~/.zsh/zsh-autocomplete

# =============================================================================
#                           Environment Setup
# =============================================================================
eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
setopt globdots
# Basic auto/tab complete:
autoload -U compinit 

# =============================================================================
#                           ZSH Core Settings
# =============================================================================
stty -ixon
# vi mode
bindkey -v
export KEYTIMEOUT=10

# =============================================================================
#                           Word Manipulation
# =============================================================================
# Backward delete word
my-backward-kill-word () {
    local WORDCHARS='*?_.[]~=&;!#$%^(){}<>:,"'"'"
    zle -f kill
    zle backward-kill-word
}
zle -N my-backward-kill-word
bindkey '^w' my-backward-kill-word

# Forward delete word
my-forward-kill-word () {
    local WORDCHARS='*?_.[]~=&;!#$%^(){}<>:,"'"'"
    zle -f kill
    zle kill-word
}

zle -N my-forward-kill-word
bindkey '^x' my-forward-kill-word
bindkey '\ed' my-forward-kill-word

# =============================================================================
#                           Key Bindings
# =============================================================================
bindkey '^Z' undo

# Paste from kill ring
bindkey '^y' yank

# Switch to vi command mode
bindkey -M viins 'kj' vi-cmd-mode
# Use vim keys in tab complete menu:

bindkey '^?' backward-delete-char
bindkey -M viins '^C' vi-cmd-mode

bindkey -M vicmd 'p' paste-from-clipboard
# Yank to the system clipboard
function vi-yank-xclip {
    zle vi-yank
   echo "$CUTBUFFER" | pbcopy -i
}

zle -N vi-yank-xclip
bindkey -M vicmd 'y' vi-yank-xclip

# =============================================================================
#                           Vi Mode Configuration
# =============================================================================
# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.
autoload edit-command-line; zle -N edit-command-line
bindkey '^v' edit-command-line

# =============================================================================
#                           Environment Variables
# =============================================================================
eval "$(starship init zsh)"
alias vim="nvim"

export PATH="/opt/homebrew/opt/node@20/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/node@20/lib"
export CPPFLAGS="-I/opt/homebrew/opt/node@20/include"
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# =============================================================================
#                           Plugin Configuration
# =============================================================================
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

# take only consecutive ctrl + d for exiting shell
set -o ignoreeof

# autocomplete plugin
# bindkey              '^I'         menu-complete
# bindkey "$terminfo[kcbt]" reverse-menu-complete

# bindkey -M menuselect '^M' .accept-line

# zsh-autosuggestions plugin maps
bindkey '^S' autosuggest-accept  

# Multiselect for fzftab
zstyle ':fzf-tab:*' fzf-flags '--bind=alt-s:toggle+down'
export FZF_DEFAULT_COMMAND="find . -maxdepth 1"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--multi
--preview-window=:hidden
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--bind '?:toggle-preview'
--bind 'ctrl-a:select-all'
--bind 'ctrl-y:execute-silent(echo {+} | pbcopy)'
--bind 'ctrl-e:execute(echo {+} | xargs -o nvim)'
--bind 'ctrl-v:execute(code {+})'
--bind ctrl-d:down,ctrl-q:up
"

# =============================================================================
#                           Completion System
# =============================================================================
# Completion conf
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# # preview directory's content with eza when completing cd
# zstyle ':fzf-tab:*' fzf-flags $FZF_PREVIEW_OPTS
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list \
    'm:{[:lower:]}={[:upper:]}' \
    '+r:|[._-]=* r:|=*' \
    '+l:|=*'
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

# =============================================================================
#                           History Configuration
# =============================================================================
# history setup
setopt SHARE_HISTORY
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt HIST_EXPIRE_DUPS_FIRST

# =============================================================================
#                           Menu Selection
# =============================================================================
# bindkey -M menuselect 'h' vi-backward-char
# bindkey -M menuselect 'k' vi-up-line-or-history
# bindkey -M menuselect 'l' vi-forward-char
# bindkey -M menuselect 'j' vi-down-line-or-history
# Add Shift+Tab to go to previous item in completion menu
bindkey -M menuselect '^[[Z' reverse-menu-complete


autoload up-line-or-beginning-search
autoload down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search


# autocompletion using arrow keys (based on history)
bindkey '^e' up-line-or-beginning-search
bindkey '^f' down-line-or-beginning-search

# =============================================================================
#                           Aliases & Functions
# =============================================================================
# aliases

alias ls='lsd -la'
alias la='lsd -a'
alias ll='lsd -al'


# Git aliases
alias ga='git add'
alias gs='git status'
alias gp='git push'
alias gP='git pull'
alias gb='git branch'
alias gch='git checkout'
alias gr='git remote'
gc() {
  git commit -m "$*"
}
gac() {
  git add -A && git commit -m "$*" 
}
gasp() {
  git add -A && git commit -m "$*" && git push
}

# Directory navigation aliases
alias cc='cd ~/Developer/'
alias c.="cd ~/.config/"
alias cs="cd ~/School/"

# Render image alias
alias icat='kitten icat'

# Enhanced cd function with directory stack
function cd() {
    if [ $# -eq 0 ]; then
        # make "popd" without args act like "cd ~"
        set "$HOME"
    elif [ "$1" = "-" ]; then
        # make "cd -" act like "popd" without args;
        # make that "-" go away
        shift
    fi

    pushd "$@" >/dev/null
}
alias -- -=popd

alias v="nvim"
alias fastfetch='fastfetch --color-keys "38;5;230" --color-output "38;5;230"'

# =============================================================================
#                           External Tools Configuration
# =============================================================================
# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/Users/stanley/.opam/opam-init/init.zsh' ]] || source '/Users/stanley/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration

# Created by `pipx` on 2024-10-06 16:12:50
export PATH="$PATH:/Users/stanley/.local/bin"

eval $(thefuck --alias)

fastfetch

