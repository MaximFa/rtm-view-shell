<#
  ast_scope_check.ps1 - the case-collision check, done on the SYNTAX TREE instead of by regex.

  Why this file exists: the regex check in tools/lint_probe.py cannot see scope, and in PowerShell an
  assignment inside a function creates a NEW LOCAL - so a function-local $lines does not clobber a
  script-level $Lines. Measured over the whole registry on 19.09: of 19 files the regex flagged,
  14 were real and 3 were benign. A tool that over-reports teaches the role to stop believing it,
  and a tool nobody believes is worse than no tool at all (coordinator-0917, 19.09).

  Verdict per collision:
    REAL   - both spellings are written in the SAME scope: one role can silently overwrite the other.
    benign - the spellings live in different scopes; the inner one is a new local.

  Usage:  pwsh -NoProfile -File tools/ast_scope_check.ps1 -Path <probe.ps1>
  Exit 1 if any REAL collision is found, 0 otherwise. Unparseable files are reported, not guessed at.

  LIMIT: this runs under PowerShell 7's parser; the operator executes under 5.1. Scope rules are the
  same in both, but a file 5.1 accepts and 7 rejects will be reported here as UNPARSEABLE.
#>
param([Parameter(Mandatory)][string]$Path)

$parseErrors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) {
  Write-Output ("{0} : UNPARSEABLE - {1}" -f $Path, $parseErrors[0].Message)
  exit 2
}

function Get-EnclosingScope($node) {
  $walker = $node
  while ($walker.Parent) {
    if ($walker.Parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
      return 'function:' + $walker.Parent.Name
    }
    $walker = $walker.Parent
  }
  return 'script'
}

$written = @()
foreach ($assignment in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
  if ($assignment.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
    $written += [pscustomobject]@{
      Name  = $assignment.Left.VariablePath.UserPath
      Scope = (Get-EnclosingScope $assignment)
      Line  = $assignment.Extent.StartLineNumber
    }
  }
}
foreach ($loop in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ForEachStatementAst] }, $true)) {
  $written += [pscustomobject]@{
    Name  = $loop.Variable.VariablePath.UserPath
    Scope = (Get-EnclosingScope $loop)
    Line  = $loop.Extent.StartLineNumber
  }
}

$realFound = $false
foreach ($group in ($written | Group-Object { $_.Name.ToLower() })) {
  $spellings = @($group.Group.Name | Select-Object -Unique)
  if ($spellings.Count -le 1) { continue }
  $clashingScopes = @($group.Group | Group-Object Scope | Where-Object { @($_.Group.Name | Select-Object -Unique).Count -gt 1 })
  $forms = ($spellings | ForEach-Object { '$' + $_ }) -join ' / '
  if ($clashingScopes) {
    $realFound = $true
    $lines = ($group.Group | Sort-Object Line | ForEach-Object { $_.Line }) -join ', '
    Write-Output ("{0} : REAL   {1}   same scope [{2}]   lines {3}" -f $Path, $forms, (($clashingScopes.Name) -join '/'), $lines)
  } else {
    Write-Output ("{0} : benign {1}   different scopes - the inner one is a new local" -f $Path, $forms)
  }
}
if ($realFound) { exit 1 } else { exit 0 }
