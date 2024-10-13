# vim: ft=zsh
#
# For profiling loading time of zsh we can use
# zprof. We should add `zmodload zsh/zprof` in to the beginning of
# zshrc file and `zprof` in the end of file

export USE_PATCHED_FONT="false"
export EDITOR=vim

#Unfortunately, zsh's default history file size is limited to 10000 lines by default and will truncate the history to this length by deduplicating entries and removing old data.
#Adding the following lines to .zshrc will remove the limits and deduplication of the history file.
export HISTSIZE=1000000000
export SAVEHIST=$HISTSIZE
setopt EXTENDED_HISTORY

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
unsetopt HIST_VERIFY

if [[ $- == *i* ]]; then # only if we are in interactive mode
  if [ "$(command -v tmux)"  ]; then # tmux installed
    if [ -z "$INSIDE_EMACS" ]; then # not inside emacs
      if [ "$TERM_PROGRAM" != "vscode" ]; then # not inside vscode
        if [ -z "$TMUX" ]; then # not inside tmux
          if [ -z "$WARP_IS_LOCAL_SHELL_SESSION" ]; then # not inside warp terminal
            N=$(tmux ls | grep -v attached | head -1 | cut -d: -f1)
            if [[ -z $N ]]; then
              # if all sessions are attached or no any session
              # create a new one. This allow us to open several terminals
              # with own sessions
              tmux -2 &>/dev/null && exit
            else
              # -2 for supporting colors (256)
              (tmux attach || tmux -2) &>/dev/null && exit # exit from shell after exit tmux
            fi
          fi
        fi
      fi
    fi
  fi
fi

# add a directory to the PATH variable only if it's not already in it
# $1: the directory to add
# $2: "after" to add it at the end, otherwise it's added at the beginning
pathmunge() {
  [ -d "$1" ] && case ":$PATH:" in
    *:$1:*) ;;
    *) [ "$2" = "after" ] && PATH="$PATH:$1" || PATH="$1:$PATH"
  esac
  export PATH
}

# save results of a command in a cache file and source it
# $1: command name
# $2: comand source code
_eval_and_cache() {
  CMD_NAME="$1"
  CMD_CODE="$2"

  if [ -z "$CMD_NAME" -o -z "$CMD_CODE" ]; then
    return 1
  fi

  CMD_CACHE="$HOME/.$CMD_NAME-init"
  if [ "${commands[$CMD_NAME]}" -nt "$CMD_CACHE" -o ! -f "$CMD_CACHE" ]; then
    eval $CMD_CODE >! "$CMD_CACHE"
  fi
  source "$CMD_CACHE"
  unset CMD_CACHE
  unset CMD_CODE
  unset CMD_NAME
}

# Instal and load zgen (zsh plugin manager)
[[ ! -d $HOME/.zgen ]] && git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
[[ -f $HOME/.zgen/zgen.zsh ]] && source $HOME/.zgen/zgen.zsh 2>/dev/null

if [ "$(command -v zgen)"  ]; then
  if ! zgen saved; then
        # to reset zgen cache run `zgen reset`

        # Load various lib files
        zgen load robbyrussell/oh-my-zsh lib/

        # Bundles
        zgen oh-my-zsh plugins/git
        zgen oh-my-zsh plugins/vi-mode

        zgen load Aloxaf/fzf-tab
        zgen load zsh-users/zsh-history-substring-search
        zgen load zsh-users/zsh-syntax-highlighting
        zgen load "zsh-users/zsh-autosuggestions" "zsh-autosuggestions.zsh"
        zgen load zsh-users/zsh-completions src

        zgen oh-my-zsh plugins/npm

        # Theme
        zgen oh-my-zsh themes/robbyrussell
        zgen save
  fi
fi

if [ -d $HOME/.local/share/zsh/completion ]; then
  fpath=($HOME/.local/share/zsh/completion $fpath)
  compinit -u
fi

PROMPT='%/> '

alias mk="mkdir -p"
alias t="touch"
alias q="exit"
alias rm="rm -rf"
alias pl="sudo"
alias mimimi="git pull --rebase"
alias c="cd"
alias k9="kill -9"
alias disc='df -h'
alias v="$([ "$(command -v nvim)" ] && echo "nvim" || echo "vim")"
alias co="$([ "$(command -v code-insiders)" ] && echo "code-insiders -n " || echo "code -n ")"
alias zshprofiling="time zsh -i -c exit"
alias n="npm"

if [ "$(command -v nvim)" ]
then
  autoload -U edit-command-line
  zle -N edit-command-line
  bindkey '^xe' edit-command-line
  bindkey '^x^e' edit-command-line
  bindkey -M vicmd v edit-command-line
  export EDITOR=nvim
fi

# vi-mode
# add to vim mode some emacs key bindings
bindkey '\C-r' history-incremental-search-backward
bindkey '\C-s' history-incremental-search-forward
bindkey '\C-w' backward-delete-word
bindkey '\C-a' beginning-of-line
bindkey '\C-e' end-of-line
bindkey ' ' magic-space

# Jump words with CTRL-arrow
# To know the code of a key, execute cat, press the key(Ctrl+Left), enter and Ctrl+C
bindkey '^[OD' backward-word
bindkey '^[OC' forward-word

bindkey -M vicmd '\C-r' history-incremental-search-backward
bindkey -M vicmd '\C-a' beginning-of-line
bindkey -M vicmd '\C-e' end-of-line
bindkey -M vicmd '?' history-incremental-search-forward

# zsh-syntax-highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[command]='fg=10'
ZSH_HIGHLIGHT_STYLES[alias]=$ZSH_HIGHLIGHT_STYLES[command]
ZSH_HIGHLIGHT_STYLES[builtin]=$ZSH_HIGHLIGHT_STYLES[command]
ZSH_HIGHLIGHT_STYLES[function]=$ZSH_HIGHLIGHT_STYLES[command]

# zsh-history-substring-search
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
if [ "$(command -v autosuggest_start)"  ]; then
  # Enable autosuggestions automatically
  zle-line-init() {
    autosuggest_start
  }
  zle -N zle-line-init

  # use ctrl+t to toggle autosuggestions(hopefully this wont be needed as
  # zsh-autosuggestions is designed to be unobtrusive)
  bindkey '^T' autosuggest-toggle
fi

# Add .local/bin to PATH
pathmunge "$HOME/.local/bin"

# Fix problem with intelliji window focus
if [[ `uname` -ne 'Darwin' ]]; then
  export _JAVA_AWT_WM_NONREPARENTING=1;
fi

# https://github.com/ajeetdsouza/zoxide
if [ "$(command -v zoxide)" ]
then
  _eval_and_cache 'zoxide' 'zoxide init zsh --cmd z --hook pwd'
  function ff(){
    # translate `f d/ui` -> `z d ui`
    z $(echo $@ | sed 's/\// /g')
  }
  alias f="ff"
fi

# prefer zoxide over fasd
if [ "$(command -v fasd)" ] && [ ! "$(command -v zoxide)" ]
then
  _eval_and_cache 'fasd' \
    'fasd --init posix-alias zsh-{hook,ccomp,ccomp-install,wcomp,wcomp-install}'

  function ff(){
    local ARGUMENTS
    local ARGV
    local LARG

    if [ ! "$1" ]
    then
      cd "$(fasd -Rl | head -1)"
      return
    fi

    if [ -d "$1" ]
    then
      cd "$1"
      return
    fi

    if [ $# -eq 1 ]
    then
      ARGUMENTS="${1//\// }"
      cd "$(fasd -a ${(s/ /)ARGUMENTS})"
      return
    fi

    if [ $# -ge 2 ]
    then
      ARGV=("$@")
      LARG="$(($# - 1))"
      ARGUMENTS="${ARGV[$#]}"
      # first arguments command
      # last argument is a path
      ARGUMENTS="${ARGUMENTS//\// }"
      fasd -e "${ARGV[@]:0:$LARG}" -a ${(s/ /)ARGUMENTS}
      return
    fi

    cd "$(fasd -a $@)"
  }

  alias f="ff"
fi

# https://github.com/junegunn/fzf
if [ ! -d "$HOME/.fzf"  ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  $HOME/.fzf/install
fi

if [ -f "$HOME/.fzf.zsh"  ]; then
  source "$HOME/.fzf.zsh"

  function insert-fzf-path-in-command-line() {
    local selected_path
    echo
    selected_path=$(find * -type f | fzf > selected) || return
    eval 'LBUFFER="$LBUFFER$selected_path"'
    zle reset-prompt
  }

  zle -N insert-fzf-path-in-command-line

  bindkey "^F" "insert-fzf-path-in-command-line"
fi

# https://minikube.sigs.k8s.io/docs/commands/completion/
if [ -f "$HOME/.minikube-completion" ]; then
  . $HOME/.minikube-completion
fi

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/#zsh
if [ "$(command -v kubectl)"  ]; then
  _eval_and_cache 'kubectl' 'kubectl completion zsh'
fi

# http://www.gitignore.io/cli
if [ "$(command -v curl)" ]
then
  function gi() {
    curl -sL https://www.gitignore.io/api/$@
  }
fi

# This loads nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh" --no-use
  # setup default node version manually to speed up shell loading
  if [ -f "$NVM_DIR/alias/default" ]; then
     NODE_VERSION=$(cat "$NVM_DIR/alias/default")
     PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"
  fi
fi

if [ "$(command -v nvm)" ]
then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc() {
    local nvmrc_path="$(nvm_find_nvmrc)"

    if [ -n "$nvmrc_path" ]; then
      local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
      if [ "$nvmrc_node_version" = "N/A" ]; then
        nvm install
      elif [ -z "$(command -v node)" ] || [ "$nvmrc_node_version" != "$(node --version)" ]; then
        nvm use
      fi
    fi
  }

  load-nvmrc

  # This loads nvm bash_completion
  [ -s "$NVM_DIR/bash_completion" ] && \
    . "$NVM_DIR/bash_completion"
fi

# Is a tool for managing parallel versions of multiple
# Java based Software Development Kits on systems.
# https://sdkman.io
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] \
  && source "$HOME/.sdkman/bin/sdkman-init.sh"

export DENO_INSTALL="$HOME/.deno"
pathmunge "$DENO_INSTALL/bin"

# Ruby version manager
pathmunge "$HOME/.rvm/bin" after
[[ -s "$HOME/.rvm/scripts/rvm" ]] \
  && source "$HOME/.rvm/scripts/rvm"

# Run vim version manager
[[ -s "$HOME/.vvm/etc/login" ]] \
  && source "$HOME/.vvm/etc/login"

# Opt-out of Homebrew's analytics
# Learn more about what you are opting in to at
# https://docs.brew.sh/Analytics
export HOMEBREW_NO_ANALYTICS=1

# Load custom zsh scripts
[[ -d "$HOME/.local/share/zsh" ]] && \
  for file in "$HOME/.local/share/zsh"/*.zsh; do
    source "$file"
  done 2>/dev/null

# https://mise.jdx.dev
if [ "$(command -v mise)"  ]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

[[ -s "$HOME/.sh.local" ]] && source "$HOME/.sh.local"
[[ -s "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
