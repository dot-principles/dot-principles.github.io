<#
.SYNOPSIS
    Uninstalls .principles assets via bash.
.DESCRIPTION
    Requires bash on PATH (e.g. Git for Windows: https://git-scm.com/download/win).
    All arguments are forwarded to uninstall.sh unchanged.
    Use forward slashes or relative paths for directory arguments.
.EXAMPLE
    .\uninstall.ps1
    .\uninstall.ps1 ~/projects/my-app
    .\uninstall.ps1 ~/projects/my-app --purge --dry-run
    .\uninstall.ps1 ~/projects/my-app --purge
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
        $quotedArgs = ($args | ForEach-Object { "'" + ($_ -replace "'", "'\\''") + "'" }) -join ' '
        bash -c "PRINCIPLES_WIN_HOME='$winHome' bash uninstall.sh $quotedArgs"
    } else {
        & bash uninstall.sh @args
    }
    $exit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $exit
