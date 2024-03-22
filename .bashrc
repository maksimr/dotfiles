export BASH_SILENCE_DEPRECATION_WARNING=1

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

[ -f "/opt/homebrew/bin/brew" ] && \
  eval "$(/opt/homebrew/bin/brew shellenv)"

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

if [ -d "$HOME/.bashrc.d" ]; then
  for i in $(ls -A $HOME/.bashrc.d/); do
    source "$HOME/.bashrc.d/$i";
  done
fi
