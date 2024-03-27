$env:EDITOR = $env:VISUAL = 'vim'

Set-PSReadLineOption -EditMode Vi

Set-PSReadLineKeyHandler -Chord "Ctrl+r" -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function ForwardChar
Set-PSReadLineKeyHandler -Chord "Ctrl+e" -Function EndOfLine
Set-PSReadLineKeyHandler -Chord "Ctrl+a" -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord "Ctrl+w" -Function BackwardDeleteWord

Set-PSReadLineKeyHandler -ViMode Command -Chord "Ctrl+r" -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -ViMode Command -Chord "Ctrl+e" -Function EndOfLine
Set-PSReadLineKeyHandler -ViMode Command -Chord "Ctrl+a" -Function BeginningOfLine
Set-PSReadLineKeyHandler -ViMode Command -Chord "Ctrl+w" -Function BackwardDeleteWord
