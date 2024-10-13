$env:EDITOR = $env:VISUAL = 'vim'

[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
[System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
$env:LESSCHARSET = "utf-8"

$PSStyle.FileInfo.Directory = $PSStyle.Foreground.BrightCyan

Set-PSReadLineOption -Colors @{ InlinePrediction = '#676767' }
Set-PSReadLineOption -Colors @{ Command = "green" }

Set-PSReadLineOption -EditMode Vi

Set-Variable -Name MaximumHistoryCount -Value 30000

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
  function Find-FzfExe() {
    if ($IsWindows) { $AppNames = @('fzf-*-windows_*.exe', 'fzf.exe') }
    if ($IsMacOS) { $AppNames = @('fzf-*-darwin_*', 'fzf') }
    if ($IsLinux) { $AppNames = @('fzf-*-linux_*', 'fzf') }
    # find it in our path:
    $AppNames | ForEach-Object {
      $Private:FzfLocation = Get-Command $_ -ErrorAction Ignore | Select-Object -ExpandProperty Source
      if ($null -ne $FzfLocation) {
        return Resolve-Path $FzfLocation
      }
    }
  }

  function Invoke-Fzf {
    param(
      [string]$Arguments
    )

    Begin {
      $process = New-Object System.Diagnostics.Process
      $process.StartInfo.FileName = Find-FzfExe
      $process.StartInfo.Arguments = $Arguments
      $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
      $process.StartInfo.RedirectStandardInput = $true
      $process.StartInfo.RedirectStandardOutput = $true
      $process.StartInfo.UseShellExecute = $false
      if ($pwd.Provider.Name -eq 'FileSystem') {
        $process.StartInfo.WorkingDirectory = $pwd.ProviderPath
      }
  
      $process.Start() | Out-Null
    }
  
    Process { 
      function ConvertTo-String {
        param ($item)
        $str = $null
        if ($item -is [System.String]) { 
          $str = $item 
        }
        elseif ( 
          $null -eq $item.FullName && 
          $null -eq $item.FullName.Name
        ) {
          $str = $item.FullName.Name.ToString()
        }
        return $str
      }

      foreach ($item in $Input) {
        $strItem = ConvertTo-String $item
        if (![System.String]::IsNullOrWhiteSpace($strItem)) {
          $process.StandardInput.WriteLine($strItem) 
        }
      }
    }
  
    End { 
      $output = $process.StandardOutput.ReadToEnd().Trim();
      $process.WaitForExit()
      $output
    }
  }

  Set-PSReadLineKeyHandler -Chord "Ctrl+r" -ScriptBlock {
    $command = ""

    if ($IsMacOS) {
      # On macOS we need to use separate process for fzf
      # otherwise it will run as background process and won't be able to read input
      # and show output
      $command = `
        Get-Content (Get-PSReadlineOption).HistorySavePath |`
        Select-Object -Unique |`
        Invoke-Fzf -Arguments "--tac --no-sort"
    }
    else {
      $command = `
        Get-Content (Get-PSReadlineOption).HistorySavePath |`
        awk '!a[$0]++' |`
        fzf --tac --no-sort
    }

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

function Add-Alias($name, $alias) {
  $func = @"
function global:$name {
  `$expr = ('$alias ' + (( `$args | % { if (`$_.GetType().FullName -eq "System.String") { "``"`$(`$_.Replace('``"','````"').Replace("'","``'"))``"" } else { `$_ } } ) -join ' '))
  Invoke-Expression `$expr
}
"@
  $func | Invoke-Expression
}

<#
.SYNOPSIS
# Use bat instead of cat
#>
if (Get-Command "bat" -errorAction SilentlyContinue) {
  Add-Alias cat 'bat -p'
}
