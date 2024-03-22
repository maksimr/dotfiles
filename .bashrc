# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

if [[ $- == *i* ]]; then # only if we are in interactive mode
  if [ "$(command -v tmux)"  ]; then # tmux installed
    if [ -z "$INSIDE_EMACS" ]; then # not inside emacs
      if [ "$TERM_PROGRAM" != "vscode" ]; then # not inside vscode
        if [ -z "$TMUX" ]; then # not inside tmux
          if [ -z "$WARP_IS_LOCAL_SHELL_SESSION" ]; then # not inside warp terminal
            # -2 for supporting colors (256)
            (tmux attach || tmux -2) &>/dev/null && exit # exit from shell after exit tmux
          fi
        fi
      fi
    fi
  fi
fi

export USE_PATCHED_FONT="false"
export EDITOR=vim

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=100000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;31m\]➜\[\033[00m\]  ${debian_chroot:+($debian_chroot)}\[\033[01;36m\]\u@\h\[\033[00m\]:\[\033[01;36m\]\w\[\033[00m\] '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

if [ -z "$(type -t __git_ps1)" ] && [ -f "$HOME/.git-prompt.sh" ]; then
    . "$HOME/.git-prompt.sh"
fi

if [ "$(type -t __git_ps1)" = "function" ]; then
  export GIT_PS1_SHOWCOLORHINTS=1
  export GIT_PS1_SHOWDIRTYSTATE=1
  PS1+='$(__git_ps1 "\[\033[01;34m\]git:(%s\[\033[01;34m\])\[\033[00m\]") '
fi

alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
# For MacOs use:
# brew install bash-completion
if [ -z "$BASH_COMPLETION" ]; then
  if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
      . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
      . /etc/bash_completion
    elif [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
      . /opt/homebrew/etc/profile.d/bash_completion.sh
    elif [ -f $HOME/.local/share/bash-completion/bash_completion ]; then
      . $HOME/.local/share/bash-completion/bash_completion
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

  SHELL_NAME="$(ps -p $$ -o comm=)"
  CMD_CACHE="$HOME/.$CMD_NAME-init-$SHELL_NAME.cache"
  if [ "${commands[$CMD_NAME]}" -nt "$CMD_CACHE" -o ! -f "$CMD_CACHE" ]; then
    eval "$CMD_CODE" > "$CMD_CACHE"
  fi
  source "$CMD_CACHE"
  unset CMD_CACHE
  unset CMD_CODE
  unset CMD_NAME
}

SHELL_NAME="$(ps -p $$ -o comm=)"
if [ "$SHELL_NAME" = "bash" ]; then
  for i in {1..10}; do
    VALUE=$(eval "printf '%0.s../' {1..$i}")
    KEY=$(eval "printf '%0.s.' {1..$i}")
    eval "alias '.$KEY'='cd $VALUE'"
  done
fi

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
alias n="npm"

if [ "$(command -v nvim)" ]
then
  export EDITOR=nvim
fi

# Add .local/bin to PATH
pathmunge "$HOME/.local/bin"

# Fix problem with intelliji window focus
if [[ `uname` -ne 'Darwin' ]]; then
  export _JAVA_AWT_WM_NONREPARENTING=1;
fi

if [ "$(command -v fasd)" ]
then
  SHELL_NAME="$(ps -p $$ -o comm=)"
  _eval_and_cache 'fasd' \
    "fasd --init posix-alias $SHELL_NAME-{hook,ccomp,ccomp-install,wcomp,wcomp-install}"

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
      cd "$(fasd -a ${ARGUMENTS//\// })"
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
      fasd -e "${ARGV[@]:0:$LARG}" -a ${ARGUMENTS//\// }
      return
    fi

    cd "$(fasd -a "$@")"
  }

  alias f="ff"
fi

if [ ! -d "$HOME/.fzf"  ] && [ -n "$FZF_AUTOINSTALL" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  $HOME/.fzf/install
fi

SHELL_NAME="$(ps -p $$ -o comm=)"
if [ -f "$HOME/.fzf.$SHELL_NAME"  ]; then
  source "$HOME/.fzf.$SHELL_NAME"
fi

# https://minikube.sigs.k8s.io/docs/commands/completion/
if [ -f "$HOME/.minikube-completion" ]; then
  . $HOME/.minikube-completion
fi

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/#bash
if [ "$(command -v kubectl)"  ]; then
  SHELL_NAME="$(ps -p $$ -o comm=)"
  if [ "$SHELL_NAME" != "bash" ] || [ -n "$BASH_COMPLETION" ]; then
    _eval_and_cache "kubectl' 'kubectl completion $SHELL_NAME"
  fi
fi

# http://www.gitignore.io/cli
if [ "$(command -v curl)" ]
then
  function gi() {
    curl -sL https://www.gitignore.io/api/$*
  }
fi

# This loads nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

typeset CHPWD_COMMAND=""

add-chpwd-hook() {
  CHPWD_COMMAND="${CHPWD_COMMAND:+$CHPWD_COMMAND;}$1"
}

_chpwd_hook() {
  local f

  # run commands in CHPWD_COMMAND variable on dir change
  if [[ "$PREVPWD" != "$PWD" ]]; then
    local IFS=$';'
    for f in $CHPWD_COMMAND; do
      "$f"
    done
    unset IFS
  fi
  # refresh last working dir record
  export PREVPWD="$PWD"
}

# add `;` after _chpwd_hook if PROMPT_COMMAND is not empty
PROMPT_COMMAND="_chpwd_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

if [ "$(command -v nvm)" ]
then
  add-chpwd-hook load-nvmrc
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

  # This loads nvm bash_completion
  [ -s "$NVM_DIR/bash_completion" ] && \
    . "$NVM_DIR/bash_completion"
fi

# https://www.npmjs.com/package/@githubnext/github-copilot-cli
if [ "$(command -v github-copilot-cli)"  ]; then
  _eval_and_cache 'github-copilot-cli' 'github-copilot-cli alias -- "$0"'
else
  copilot_lazy-init () {
    npm install -g @githubnext/github-copilot-cli
    unalias '??'
    _eval_and_cache 'github-copilot-cli' 'github-copilot-cli alias -- "$0"'
    copilot_what-the-shell "$@"
  };
  alias '??'='copilot_lazy-init'
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
