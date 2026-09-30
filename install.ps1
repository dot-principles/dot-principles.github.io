<#
.SYNOPSIS
    Installs .principles assets via bash.
.DESCRIPTION
    Requires bash on PATH (e.g. Git for Windows: https://git-scm.com/download/win).
    All arguments are forwarded to install.sh unchanged.
    Use forward slashes or relative paths for directory arguments.
.EXAMPLE
    .\install.ps1 ~/projects/my-app
    .\install.ps1 vendor ~/projects/my-app
    .\install.ps1 --list ~/projects/my-app
#>

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error 'bash not found. Install Git for Windows: https://git-scm.com/download/win'
    exit 1
}

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# Detect whether bash is Git Bash (pc-msys/mingw) or WSL (linux-gnu).
# WSL bash does not inherit PowerShell environment variables, so we must
# inject the Windows home directory inline via the command string.
$bashVersion = bash --version 2>&1 | Select-Object -First 1
$isWSL = $bashVersion -notmatch 'msys|mingw'

Push-Location $scriptDir
try {
    if ($isWSL) {
        $winHome = ($env:USERPROFILE -replace '\\', '/') -replace "'", "'\''"
        $quotedArgs = ($args | ForEach-Object { "'" + (($_ -replace '\\', '/') -replace "'", "'\\''") + "'" }) -join ' '
        bash -c "PRINCIPLES_WIN_HOME='$winHome' bash install.sh $quotedArgs"
    } else {
        $convertedArgs = $args | ForEach-Object { $_ -replace '\\', '/' }
        & bash install.sh @convertedArgs
    }
    $exit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $exit
