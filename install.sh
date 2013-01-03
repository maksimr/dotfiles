#!/bin/bash
# Installation script

DOTFILE_TARGET="$HOME/.dotfile"

if [ -d "$DOTFILE_TARGET"  ]; then
  echo "=> Dotfile is already installed in $DOTFILE_TARGET, trying to update"
  echo -ne "\r=> "
  cd $DOTFILE_TARGET && git pull
  exit
fi

git clone git://github.com/maksimr/dotfiles.git $DOTFILE_TARGET

if [ -s "$DOTFILE_TARGET/dot.bash"  ]
then
  echo "   Load dotfile script..."
  echo

  . "$DOTFILE_TARGET/dot.bash"
  dot init

  echo
  echo "   Dotfiles was installed successfully."
  echo "   You can add $DOTFILE_TARGET/dot.bash to your .bashrc or .zshrc. If it is not already"
  echo "   In order to use the command 'dot'"
  echo
else
  echo -e "   Sorry something went wrong. Dotfiles doesn't installed"
fi
