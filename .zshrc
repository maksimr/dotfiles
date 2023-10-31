# vim: ft=zsh
#
# For profiling loading time of zsh we can use
# zprof. We should add `zmodload zsh/zprof` in to the beginning of
# zshrc file and `zprof` in the end of file


export USE_PATCHED_FONT="false"
export EDITOR=vim
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


# install zgen
if [ ! -d ~/.zgen ]; then
  git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
fi

# load zgen
if [ -f ~/.zgen/zgen.zsh ]; then
  . ~/.zgen/zgen.zsh 2>/dev/null
fi


ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=black,bold"

if [ "$(command -v zgen)"  ]; then
  if ! zgen saved; then

        # Load various lib files
        zgen load robbyrussell/oh-my-zsh lib/

        # Bundles
        zgen oh-my-zsh plugins/git
        zgen oh-my-zsh plugins/vundle
        zgen oh-my-zsh plugins/vi-mode
        zgen oh-my-zsh plugins/command-not-found

        zgen load Aloxaf/fzf-tab
        zgen load zsh-users/zsh-history-substring-search
        zgen load zsh-users/zsh-syntax-highlighting
        zgen load "zsh-users/zsh-autosuggestions" "zsh-autosuggestions.zsh"
        zgen load zsh-users/zsh-completions src

        zgen load Tarrasch/zsh-bd

        # Node Plugins
        zgen oh-my-zsh plugins/npm
        zgen oh-my-zsh plugins/node

        # Theme
        zgen oh-my-zsh themes/robbyrussell
        zgen save
  fi
fi

HISTSIZE=100000
SAVEHIST=100000

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[cyan]%}%n(%m):%~ %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

CUSTOM_BIN_PATH_LIST=(
  "$HOME/.local/bin"
  "$HOME/.go/bin"
)
for BPATH in $CUSTOM_BIN_PATH_LIST; do
  case ":$PATH:" in
    *:"$BPATH":*) ;;
    *) PATH="$BPATH:$PATH" ;;
  esac
done

# Global alias for zsh
# vim: ft=zsh
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
alias vo="v -c 'set filetype=bash' -n"
if [ "$(command -v nvim)" ]
then
  autoload -U edit-command-line
  zle -N edit-command-line
  bindkey '^xe' edit-command-line
  bindkey '^x^e' edit-command-line
  bindkey -M vicmd v edit-command-line
  export EDITOR=nvim
fi

alias co="$([ "$(command -v code-insiders)" ] && echo "code-insiders -n " || echo "code -n ")"

# change some aliases if grc installed
if [ "$(command -v grc)"  ]
then
  alias ll='grc ls -lFh --color=yes'
  alias ping="grc ping"
  alias traceroute="grc traceroute"
  alias make="grc make"
  alias diff="grc diff"
  alias cvs="grc cvs"
  alias netstat="grc netstat"
  alias logc="grc cat"
  alias logt="grc tail"
  alias logh="grc head"
fi

alias zshprofiling="/usr/bin/time zsh -i -c exit"
alias iie="curl -s https://raw.githubusercontent.com/xdissent/ievms/master/ievms.sh | bash"

# Global bindkey file
# vim: ft=zsh

# vi-mode plugin
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

# XXX optimization loading fasd
fasd_cache="$HOME/.fasd-init-bash"
if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache"  ]; then
  fasd --init auto >| "$fasd_cache"
fi
source "$fasd_cache"
unset fasd_cache

# fasd
# vim: ft=zsh
if [ "$(command -v fasd)" ]
then

  #eval "$(fasd --init auto)"

  # more coolest fasd
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

# http://www.gitignore.io/cli
if [ "$(command -v curl)" ]
then
  function gi() {
    curl -sL https://www.gitignore.io/api/$@
  }
fi

# Load scripts
# vim: ft=zsh

function {
local scripts
scripts=(
  # XXX TODO optimize loading nvm.sh
  # 10ms loading nvm.sh
  ~/.nvm/nvm.sh
  ~/.vvm/etc/login
)

for src in $scripts
do
  . $src 2>/dev/null
done
}

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

# Different configuration for oh-my-zsh plugins
# vim: ft=zsh

# zsh-syntax-highlighting plugin
# Redifine colors
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'

# zsh-history-substring-search
# bind UP and DOWN arrow keys
# bind k and j for VI mode
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
# bind P and N like EMACS
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# Setup zsh-autosuggestions
if [ "$(command -v autosuggest_start)"  ]
then
  # Enable autosuggestions automatically
  zle-line-init() {
  autosuggest_start
}
zle -N zle-line-init

    # use ctrl+t to toggle autosuggestions(hopefully this wont be needed as
    # zsh-autosuggestions is designed to be unobtrusive)
    bindkey '^T' autosuggest-toggle
fi

# Fix problem with intelliji window focus
if [[ `uname` -ne 'Darwin' ]]; then
  export _JAVA_AWT_WM_NONREPARENTING=1;
fi

# https://github.com/junegunn/fzf
if [ ! -d "$HOME/.fzf"  ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

if [ -f "$HOME/.fzf.zsh"  ]; then
  source ~/.fzf.zsh

    # aliases
    # fkill - kill process
    function fkill() {
      ps -ef | sed 1d | fzf -m | awk '{print $2}' | xargs kill -${1:-9}
    }

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


function idea() {
  declare -a ideargs=()
  declare -- wait=""

  for o in "$@"; do
    if [[ "$o" = "--wait" || "$o" = "-w" ]]; then
      wait="-W"
      o="--wait"
    fi
    if [[ "$o" =~ " " ]]; then
      ideargs+=("\"$o\"")
    else
      ideargs+=("$o")
    fi
  done

  idea_script=$(find "$HOME/Library/Application Support/JetBrains/Toolbox/apps/IDEA-U/ch-0" -name "idea" | tail -n 1)
  open -na "$idea_script" $wait --args "${ideargs[@]}"
}

# https://minikube.sigs.k8s.io/docs/commands/completion/
if [ -f "$HOME/.minikube-completion" ]; then
  # eval $(minikube -p minikube docker-env) # use miniube docker
  . $HOME/.minikube-completion
fi

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/#zsh
[[ $commands[kubectl]  ]] && source <(kubectl completion zsh)

# load .zshrc.local
if [ -f "$HOME/.zshrc.local" ]; then
  . $HOME/.zshrc.local
fi

# load local zsh files
if [ -d "$HOME/.local/zsh" ]; then
  for lzsh in $(ls "$HOME/.local/zsh"); do
    . $HOME/.local/zsh/$lzsh
  done
fi

# https://www.npmjs.com/package/@githubnext/github-copilot-cli
if [ "$(command -v github-copilot-cli)"  ]; then
 eval "$(github-copilot-cli alias -- "$0")"
fi

export GOPATH=$HOME/.go
export ANDROID_HOME=/usr/local/opt/android-sdk
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
export DVM_DIR="$HOME/.dvm"
export PATH="$DVM_DIR/bin:$PATH"
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
