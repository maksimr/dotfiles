$env:EDITOR = $env:VISUAL = 'vim'

$PSStyle.FileInfo.Directory = $PSStyle.Foreground.BrightCyan

Set-PSReadLineOption -Colors @{ InlinePrediction = '#676767' }
Set-PSReadLineOption -Colors @{ Command = "green" }

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

if (Get-Command "fzf" -errorAction SilentlyContinue) {
  Set-PSReadLineKeyHandler -Chord "Ctrl+r" -ScriptBlock {
    $command = Get-Content (Get-PSReadlineOption).HistorySavePath | awk '!a[$0]++' | fzf --tac --no-sort
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command)
  }
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
  $Local:word = $wordToComplete.Replace('"', '""')
  $Local:ast = $commandAst.ToString().Replace('"', '""')
  winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

function Register-GitCompletion {
  $githelpParseRegex = "(?<= {4})(-{1,2}(?:\w+)(?:(?:-\w+)+)?)(?:, )?(-{1,2}(?:\w+)(?:(?:-\w+)+)?)?"
  Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $ast = $commandAst.ToString()
    $words = $ast -split '\s+'
    $command = $words | Select-Object -Index 1

    $result = Invoke-Command -ScriptBlock {
      if ($ast -match "^git add") {
        $addableFiles = @(git ls-files --others --exclude-standard -m)
        $alreadyAddedFiles = @($words | Select-Object -Skip 2)
        $addableFiles | Where-Object { $_ -notIn $alreadyAddedFiles }
      }
      elseif ($ast -match "^git rm") {
        $removableFiles = git ls-files
        $removableFiles
      }
      elseif ($ast -match "^git restore") {
        $restorableFiles = git ls-files -m
        $restorableFiles
      }
      elseif ($ast -match "^git (checkout|rebase)") {
        $switchableBranches = git branch -a --format "%(refname:lstrip=2)"
        $switchableBranches
      }
      elseif ($ast -match "^git switch") {
        $switchableBranches = `
        @(git branch --format "%(refname:lstrip=2)") `
          + @(git branch -r --format "%(refname:lstrip=3)")
        $switchableBranches
      }
      else {
        $gitCommands = (git --list-cmds=main, others, alias, nohelpers)
        if (!$gitCommands.Contains($command)) {
          $gitCommands
        }
        else {
          ""
        }
      }
    }

    if ($wordToComplete -match "^-" -and $command) {
      # omg, a monstrosity
      # also 2>&1 since apparently some `git <command> -h` writes to stderr ¯\_(ツ)_/¯
      $flags = (git $command -h 2>&1 | Select-String -Pattern $githelpParseRegex).Matches | ForEach-Object { $_.Groups | Where-Object { $_.Success -and $_.Name -ne 0 } } | ForEach-Object { $_.Value }
      $result = @($result) + @($flags)
    }


    $result = @($result)
    $result -like "*$wordToComplete*"
  }
}

Register-GitCompletion

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

if (Get-Command "zoxide" -errorAction SilentlyContinue) {
  # https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#configuration
  Invoke-Expression (& { (zoxide init --cmd f --hook pwd powershell | Out-String) })
}

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
