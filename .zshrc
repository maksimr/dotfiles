# vim: ft=zsh
#
# For profiling loading time of zsh we can use
# zprof. We should add `zmodload zsh/zprof` in to the beginning of
# zshrc file and `zprof` in the end of file

export USE_PATCHED_FONT="false"
export EDITOR=vim
export HISTSIZE=100000
export SAVEHIST=100000

if [[ $- == *i* ]]; then # only if we are in interactive mode
  if [ "$(command -v tmux)"  ]; then # tmux installed
    if [ -z "$INSIDE_EMACS" ]; then # not inside emacs
      if [ "$TERM_PROGRAM" != "vscode" ]; then # not inside vscode
        if [ -z "$TMUX" ]; then # not inside tmux
          if [ -z "$WARP_IS_LOCAL_SHELL_SESSION" ]; then # not inside warp terminal
            # -2 for supporting colors (256)
            tmux -2 &>/dev/null && exit # exit from shell after exit tmux
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

# Instal and load zgen (zsh plugin manager)
[[ ! -d ~/.zgen ]] && git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
[[ -f ~/.zgen/zgen.zsh ]] && source ~/.zgen/zgen.zsh 2>/dev/null

if [ "$(command -v zgen)"  ]; then
  if ! zgen saved; then

        # Load various lib files
        zgen load robbyrussell/oh-my-zsh lib/

        # Bundles
        zgen oh-my-zsh plugins/git
        zgen oh-my-zsh plugins/vundle
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

PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[cyan]%}%n(%m):%~ %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

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
alias zshprofiling="/usr/bin/time zsh -i -c exit"

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
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'

# zsh-history-substring-search
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=black,bold"
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

# fasd
# Optimization loading fasd
fasd_cache="$HOME/.fasd-init-bash"
if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache"  ]; then
  fasd --init auto >| "$fasd_cache"
fi
source "$fasd_cache"
unset fasd_cache

if [ "$(command -v fasd)" ]
then
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
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

if [ -f "$HOME/.fzf.zsh"  ]; then
  source ~/.fzf.zsh

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
  # eval $(minikube -p minikube docker-env) # use miniube docker
  . $HOME/.minikube-completion
fi

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/#zsh
[[ $commands[kubectl]  ]] && source <(kubectl completion zsh)

# https://www.npmjs.com/package/@githubnext/github-copilot-cli
if [ "$(command -v github-copilot-cli)"  ]; then
  eval "$(github-copilot-cli alias -- "$0")"
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
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if [ "$(command -v nvm)" ]
then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc() {
    local node_version="$(nvm version)"
    local nvmrc_path="$(nvm_find_nvmrc)"

    if [ -n "$nvmrc_path" ]; then
      local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
      if [ "$nvmrc_node_version" = "N/A" ]; then
        nvm install
      elif [ "$nvmrc_node_version" != "$node_version" ]; then
        nvm use
      fi
    fi
  }

  load-nvmrc
fi

# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \
  . "$NVM_DIR/bash_completion"

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

# Opt-out of Homebrew's analytics
# Learn more about what you are opting in to at
# https://docs.brew.sh/Analytics
export HOMEBREW_NO_ANALYTICS=1

[[ -s "$HOME/.zsh.local" ]] && source "$HOME/.zsh.local"

