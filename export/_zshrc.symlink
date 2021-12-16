
#### FIG ENV VARIABLES ####
# Please make sure this block is at the start of this file.
[ -s ~/.fig/shell/pre.sh ] && source ~/.fig/shell/pre.sh
#### END FIG ENV VARIABLES ####
# vim: ft=zsh
#
# For profiling loading time of zsh we can use
# zprof. We should add `zmodload zsh/zprof` in to the beginning of
# zshrc file and `zprof` in the end of file


# Run tmux immediately after enter to terminal
# -2 for supporting colors (256)
# I Don't use patched font in terminal
export USE_PATCHED_FONT="false"
if [ "$(command -v tmux)"  ]; then
    if [ -z "$INSIDE_EMACS" ]; then
        if [ -z "$TMUX" ]; then
            tmux -2 &>/dev/null && exit # exit from shell after exit tmux
        fi
    fi
fi


# Load zgen
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

# Устанавливаем размер истории команд и файл в котором
# история будет хранится
HISTSIZE=1000
SAVEHIST=1000

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Добавляем домашнюю директори
# если ее еще нет в переменной $PATH
case ":$PATH:" in
  *:"$HOME/bin":*) ;;
  *) PATH="$HOME/bin:$PATH" ;;
esac

case ":$PATH:" in
  *:"$HOME/local/bin":*) ;;
  *) PATH="$HOME/local/bin:$PATH" ;;
esac

case ":$NODE_PATH:" in
  *:"/usr/local/lib/jsctags/":*) ;;
  *) export NODE_PATH=/usr/local/lib/jsctags/:$NODE_PATH ;;
esac

case ":$PATH:" in
  *:"$HOME/.gem/ruby/2.2.0/bin":*) ;;
  *) PATH="$HOME/.gem/ruby/2.2.0/bin:$PATH" ;;
esac

case ":$PATH:" in
  *:"$HOME/.go/bin":*) ;;
  *) PATH="$HOME/.go/bin:$PATH" ;;
esac

export EDITOR=vim

PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[cyan]%}%n(%m):%~ %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

# load dotfiles
. ~/.dotfiles/dot.bash 2>/dev/null

# Global alias for zsh
# vim: ft=zsh

alias zshrc="vim ~/.zshrc"
alias zrc="vim ~/.zshrc"
alias zr="source ~/.zshrc"
alias upd="sudo apt-get update && sudo apt-get upgrade"
alias i="sudo apt-get install "
alias u="sudo apt-get remove "
alias mk="mkdir -p"
alias t="touch"
alias q="exit"
alias rm="rm -rf"
alias nd="node --debug-brk"
alias pl="sudo"

alias l="ls"

alias gg="git grep"
alias mimimi="git pull --rebase"
alias frfrfr="g br --merged $(current_branch) | grep -v '\*\|master'"

alias c="cd"
alias f="find"
alias e="echo"
alias s="sudo"
alias sa="sudo apt-get"
alias k9="kill -9"
alias disc='df -h'

alias v="vim"
alias vl='vim "$(ls -t | head -1)"' # open last modified file in vim
# open nested last modified file, exclude dotfiles and ot directories
alias vll='vim "$(find . ! \( -path "./.*" -o  -path "*/.*" \) -type f -printf "%T@ %p\n" | sort -n | tail -1 | cut -f2- -d" " )"'
alias vrc='vim ~/.vimrc'

function kotrun() {
 _jar=$(basename $1 .kt).jar

 case "$1" in
     *.kts) kotlinc -script $1 ;;
     *.kt) kotlinc $1 -include-runtime -d $_jar && java -jar $_jar ;;
 esac
}

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
  if [ "$(command -v jshint)"  ]
  then
    alias jshint="grc jshint"
  fi
  alias kk="grc karma"
fi

# googlecl
if [ "$(command -v google)"  ]
then
  alias gdoc="google docs"
  alias gcal="google calendar"
fi

alias zshprofiling="/usr/bin/time zsh -i -c exit"
alias xm="xmodmap ~/.xmodmap"
alias iie="curl -s https://raw.githubusercontent.com/xdissent/ievms/master/ievms.sh | bash"

# load local aliases
# it can be rewrited aliases from .local/zsh
. $HOME/.local/alias 2>/dev/null

# autojump
# vim: ft=zsh
if [[ -s "/usr/share/autojump/autojump.sh" || -s "$HOME/.autojump/etc/profile.d/autojump.sh" ]]
then
  source /usr/share/autojump/autojump.sh 2>/dev/null
  source ~/.autojump/etc/profile.d/autojump.sh 2>/dev/null

  autoload -U compinit; compinit
  export AUTOJUMP_IGNORE_CASE=1
  export AUTOJUMP_KEEP_ALL_ENTRIES=1
  export AUTOJUMP_KEEP_SYMLINKS=1
  export AUTOJUMP_AUTOCOMPLETE_CMDS='cp vim'

  # more coolest autojump
  function j(){
    # if we pass directory path
    # then call 'cd'
    if [ -d "$1" ]
    then
      cd "$1"
      return
    fi

    if [ $# -le 1 ]
    then
      # XX
      # split by '/'
      # 'foo/bar' -> 'foo bar'
      local ARGUMENTS="${1//\// }"
      jj ${(s/ /)ARGUMENTS}
      return
    fi

    jj $@
  }

  # source of j command form autojump.sh `which j`
  function jj () {
    local new_path="$(autojump $@)"
    if [ -d "${new_path}" ]
    then
      echo -e "\\033[31m${new_path}\\033[0m"
      cd "${new_path}"
    else
      echo "autojump: directory '${@}' not found"
      echo "Try \`autojump --help\` for more information."
      false
    fi
  }
fi

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

# load local bindkey
# it can be rewrited bindkey from .local/zsh
. $HOME/.local/bindkey 2>/dev/null

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

  # aliases
  alias f="ff"
  alias fv="ff vim"
  alias vv="fasd -t -e vim -b viminfo"
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

# npm
if [ "$(command -v npm)"  ]
then
  alias n="npm"
  alias ni="npm install"
  alias nr="npm run"
  alias nis="npm install --save"
  alias nise="npm install --save --save-exact"
  alias nisd="npm install --save-dev"
  alias nisde="npm install --save-dev"
  alias nu="npm uninstall"
  alias nug="npm uninstall -g"
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

# peco
# peco adds flavor of interactive selection to the traditional pipe concept on UNIX.
# @link https://github.com/peco/peco
if [ "$(command -v peco)"  ]
then
    # Run Selecta in the current working directory, appending the selected path, if
    # any, to the current command.
    function insert-peco-path-in-command-line() {
        local selected_path
        # Print a newline or we'll clobber the old prompt.
        echo
        # Find the path; abort if the user doesn't select anything.
        selected_path=$(find * -type f | peco) || return
        # Append the selection to the current command buffer.
        eval 'LBUFFER="$LBUFFER$selected_path"'
        # Redraw the prompt since Selecta has drawn several new lines of text.
        zle reset-prompt
    }
    # Create the zle widget
    zle -N insert-peco-path-in-command-line
    # Bind the key to the newly created widget
    bindkey "^F" "insert-peco-path-in-command-line"
fi

# Selecta
# A fuzzy text selector for files and anything else you need to select.
# @link https://github.com/garybernhardt/selecta
if [ "$(command -v selecta)"  ]
then
    # By default, ^S freezes terminal output and ^Q resumes it. Disable that so
    # that those keys can be used for other things.
    unsetopt flowcontrol
    # Run Selecta in the current working directory, appending the selected path, if
    # any, to the current command.
    function insert-selecta-path-in-command-line() {
        local selected_path
        # Print a newline or we'll clobber the old prompt.
        echo
        # Find the path; abort if the user doesn't select anything.
        selected_path=$(find * -type f | selecta) || return
        # Append the selection to the current command buffer.
        eval 'LBUFFER="$LBUFFER$selected_path"'
        # Redraw the prompt since Selecta has drawn several new lines of text.
        zle reset-prompt
    }
    # Create the zle widget
    zle -N insert-selecta-path-in-command-line
    # Bind the key to the newly created widget
    bindkey "^S" "insert-selecta-path-in-command-line"

    # Select git branch
    function sgb(){
        git branch $@ | cut -c 3- | selecta | xargs git checkout
    }

    function scat(){
        if [ $# -eq 1 ]
        then
            cat $(find * -type f -name $@ | selecta)
        else
            cat $(find * -type f -name \* | selecta)
        fi
    }
fi

# Liquidprompt
export DISABLE_AUTO_TITLE='true'
export LP_PS1='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[cyan]%}%n(%m):%~${LP_BATT}${LP_LOAD}${LP_JOBS}${LP_PROXY}${LP_ERR} %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

if [ -f "$HOME/bin/liquidprompt" ]
then
    source $HOME/bin/liquidprompt
fi
# Liquidprompt end

# Fix problem with intelliji window focus
if [[ `uname` -ne 'Darwin' ]]; then
    export _JAVA_AWT_WM_NONREPARENTING=1;
fi

# Oracle JDK for WebStorm
if [ -d "$HOME/.local/jdk1.8.0_25" ]; then
    export WEBIDE_JDK=$HOME/.local/jdk1.8.0_25
    export JAVA_HOME=$HOME/.local/jdk1.8.0_25
fi

if [ "$(command -v tmuxinator)"  ]
then
    alias mux="tmuxinator"
fi

#https://github.com/np1/mps-youtube
if [ "$(command -v mpsyt)"  ]
then
    alias yt="mpsyt h"
fi

if [ "$(command -v thefuck)"  ]
then
    alias fuck='$(thefuck $(fc -ln -1))'
fi

# https://github.com/junegunn/fzf
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

export GOPATH=$HOME/.go
export ANDROID_HOME=/usr/local/opt/android-sdk

# https://minikube.sigs.k8s.io/docs/commands/completion/
if [ -f "$HOME/.minikube-completion" ]; then
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

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/maksimrv/.sdkman"
[[ -s "/Users/maksimrv/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/maksimrv/.sdkman/bin/sdkman-init.sh"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
export DVM_DIR="$HOME/.dvm"
export PATH="$DVM_DIR/bin:$PATH"
export PATH="$HOME/Developer/depot_tools:$PATH"

#### FIG ENV VARIABLES ####
# Please make sure this block is at the end of this file.
[ -s ~/.fig/fig.sh ] && source ~/.fig/fig.sh
#### END FIG ENV VARIABLES ####
