# check-audit-gates.ps1 - Verify that the Phase 8-10 gate language is intact, and that the audit
# core still hands over to it. The gates live in the fix-flow reference file, which dot-audit
# reads only after it has findings; the core must point at it and keep the approval rule.
# Run locally before pushing, or via CI on PRs that touch audit/skill files.
# Usage: ./tests/check-audit-gates.ps1 [repo-root]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

# Gate files: the source, and the installed copy (run `./install.sh vendor .` first).
$GateFiles = @(
    (Join-Path $RepoRoot "commands\dot\.audit-fix-flow.md"),
    (Join-Path $RepoRoot ".agents\skills\dot-audit\fix-flow.md")
)

# Core files: the command source and the installed skill. They must not lose the handover.
$CoreFiles = @(
    (Join-Path $RepoRoot "commands\dot\audit.md"),
    (Join-Path $RepoRoot ".agents\skills\dot-audit\SKILL.md")
)

$Errors = 0

function Check-Marker {
    param([string]$File, [string]$Pattern, [string]$Label)
    $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content -or -not $content.Contains($Pattern)) {
        Write-Host "FAIL [$Label]"
        Write-Host "     File   : $File"
        Write-Host "     Missing: $Pattern"
        $script:Errors++
    }
}

foreach ($file in $GateFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "FAIL [file-exists] Missing file: $file"
        $Errors++
        continue
    }

    $name = Split-Path -Leaf $file

    Check-Marker $file "## Phase 8"                                    "$name: Phase 8 heading"
    Check-Marker $file "GATE — Requires explicit user approval"        "$name: Phase 8 GATE marker"
    Check-Marker $file "Would you like me to fix these findings"       "$name: Phase 8 fix question"
    Check-Marker $file "Yes, fix them"                                 "$name: Phase 8 Yes choice"
    Check-Marker $file "No, just the report"                          "$name: Phase 8 No choice"
    Check-Marker $file "## Phase 9"                                    "$name: Phase 9 heading"
    Check-Marker $file "How would you like to proceed"                 "$name: Phase 9 commit question"
    Check-Marker $file "Commit only"                                   "$name: Phase 9 Commit-only choice"
    Check-Marker $file "Commit and push"                               "$name: Phase 9 Commit-and-push choice"
    Check-Marker $file "Exit"                                          "$name: Phase 9 Exit choice"
    Check-Marker $file "## Phase 10"                                   "$name: Phase 10 heading"
    Check-Marker $file "Shall I open a pull request"                   "$name: Phase 10 PR question"
    Check-Marker $file "Yes, open PR"                                  "$name: Phase 10 Yes choice"
    Check-Marker $file "No, keep the branch"                           "$name: Phase 10 No choice"

    # Gates use plain-text output (not an ask_user tool), so each must end with the hard-stop phrase.
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    $count = ([regex]::Matches($content, [regex]::Escape("End your response here. Do not call any tools"))).Count
    if ($count -lt 3) {
        Write-Host "FAIL [$name: hard-stop count]"
        Write-Host "     File   : $file"
        Write-Host "     Expected: at least 3 occurrences of hard-stop (Phases 8, 9, 10); found: $count"
        $Errors++
    }
}

foreach ($file in $CoreFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "FAIL [file-exists] Missing file: $file"
        $Errors++
        continue
    }

    $name = Split-Path -Leaf $file

    Check-Marker $file "fix-flow.md"                                   "$name: hands over to fix-flow.md"
    Check-Marker $file "explicit user approval"                        "$name: approval rule stated in the core"
    Check-Marker $file "does **not** grant permission to fix"          "$name: no implied permission to fix"
}

if ($Errors -eq 0) {
    Write-Host "OK  All Phase 8-10 gate markers verified in $($GateFiles.Count) files; $($CoreFiles.Count) core files hand over to them."
    exit 0
} else {
    Write-Host ""
    Write-Host "FAIL $Errors check(s) failed. The audit gate workflow is incomplete."
    exit 1
}
