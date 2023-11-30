# Install aws cli zsh completion

if command -v aws_completer >/dev/null 2>&1; then
  complete -C "$(which aws_completer)" aws
fi

