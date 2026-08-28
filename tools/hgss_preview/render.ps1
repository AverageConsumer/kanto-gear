param([string]$Output = "")

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$love = $env:LOVE_EXE
if (-not $love) {
  $command = Get-Command love.exe -ErrorAction SilentlyContinue
  if ($command) { $love = $command.Source }
}
if (-not $love) {
  $love = Join-Path $env:TEMP "love-11.5-win64\love-11.5-win64\love.exe"
}
if (-not (Test-Path -LiteralPath $love)) {
  throw "LÖVE 11.5 not found. Set LOVE_EXE to love.exe."
}
$sourceImage = Join-Path $PSScriptRoot "local\party-source.png"
if (-not (Test-Path -LiteralPath $sourceImage)) {
  throw "Missing local/party-source.png preview fixture."
}
if (-not $Output) { $Output = Join-Path $PSScriptRoot "out\party.png" }
New-Item -ItemType Directory -Path (Split-Path $Output) -Force | Out-Null
$runtime = Join-Path $env:TEMP "kg-hgss-preview"
New-Item -ItemType Directory -Path (Join-Path $runtime "local") -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "main.lua") `
  -Destination (Join-Path $runtime "main.lua") -Force
Copy-Item -LiteralPath $sourceImage `
  -Destination (Join-Path $runtime "local\party-source.png") -Force
$env:KANTO_GEAR_ROOT = $root.Replace("\", "/")
$env:KANTO_GEAR_PREVIEW_OUT = [IO.Path]::GetFullPath($Output).Replace("\", "/")
& $love $runtime
if ($LASTEXITCODE) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $Output)) { throw "Preview was not created." }
Write-Output ([IO.Path]::GetFullPath($Output))
