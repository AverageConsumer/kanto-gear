param(
  [string[]]$Languages = @("de", "es", "fr"),
  [int[]]$Generations = @(1, 2),
  [string[]]$Variants = @("light", "dark"),
  [string[]]$Screens,
  [string]$OutputRoot = (Join-Path $PSScriptRoot "out\localization")
)

$ErrorActionPreference = "Stop"
if (-not $Screens) {
  $source = Get-Content -Raw (Join-Path $PSScriptRoot "main.lua")
  $Screens = @("home", "party") + @(
    [regex]::Matches($source, 'screen == "([^"]+)"') |
      ForEach-Object { $_.Groups[1].Value })
  $Screens = @($Screens | Sort-Object -Unique)
}
$saved = @{}
foreach ($key in @("GEN", "LANGUAGE", "VARIANT", "SCREEN", "OUT")) {
  $name = "KANTO_GEAR_PREVIEW_$key"
  $saved[$name] = [Environment]::GetEnvironmentVariable($name)
}
$failures = @()
$passed = 0
try {
  foreach ($gen in $Generations) {
    foreach ($language in $Languages) {
      foreach ($variant in $Variants) {
        $env:KANTO_GEAR_PREVIEW_GEN = $gen
        $env:KANTO_GEAR_PREVIEW_LANGUAGE = $language
        $env:KANTO_GEAR_PREVIEW_VARIANT = $variant
        foreach ($screen in $Screens) {
          if ($gen -eq 1 -and $screen -like "summary_memo*") { continue }
          $env:KANTO_GEAR_PREVIEW_SCREEN = $screen
          $case = "$gen/$language/$variant/$screen"
          try {
            & (Join-Path $PSScriptRoot "render.ps1") `
              -Output (Join-Path $OutputRoot "$case.png") | Out-Null
            $passed++
          } catch {
            $failures += "$case : $_"
          }
        }
        Write-Output "$gen/$language/$variant complete"
      }
    }
  }
} finally {
  foreach ($name in $saved.Keys) {
    [Environment]::SetEnvironmentVariable($name, $saved[$name])
  }
}
Write-Output "$passed render checks passed; $($failures.Count) failed"
if ($failures.Count) { throw ($failures -join "`n") }
