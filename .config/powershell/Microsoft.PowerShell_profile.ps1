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

# execute EndOfLine or AcceptSuggestion by single Ctrl+e
Set-PSReadLineKeyHandler -Chord "Ctrl+e" -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion()
    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
}
Set-PSReadLineKeyHandler -Chord "RightArrow" -Function ForwardWord

Set-PSReadlineOption -BellStyle None

Set-PSReadLineKeyHandler -Chord Ctrl+r -ScriptBlock {
  $command = Get-Content (Get-PSReadlineOption).HistorySavePath | awk '!a[$0]++' | fzf --tac
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command)
}

function Quit { exit }
Set-Alias -Name q -Value Quit

Set-Alias v 'vim'
if (Get-Command "nvim" -errorAction SilentlyContinue) {
  Set-Alias v 'nvim'
}
Set-Alias mk 'mkdir'
Set-Alias t 'touch'
Set-Alias htop 'ntop'
Set-Alias top 'ntop'

# https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#configuration
Invoke-Expression (& { (zoxide init --cmd f --hook pwd powershell | Out-String) })

<#
.SYNOPSIS
# Runs Github Copilot CLI with shell template
#>
function ?? { 
    gh copilot suggest -t shell $args
}

<#
.SYNOPSIS
# Runs Github Copilot CLI with powershell template
#>
function ps? { 
    gh copilot suggest -t shell ('Use powershell to ' + $args)
}

<#
.SYNOPSIS
# Use bat instead of cat
#>
if (Get-Command "bat" -errorAction SilentlyContinue) {
  Set-Alias cat 'bat -p'
}
