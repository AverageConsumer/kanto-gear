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
$sourceImages = Get-ChildItem (Join-Path $PSScriptRoot "local") -Filter "*.png"
if ($sourceImages.Count -lt 6) {
  throw "Missing local Pokemon sprite fixtures."
}
$explorer = $env:KANTO_GEAR_PREVIEW_SCREEN -like "explorer*"
$overworldFiles = @{}
if ($explorer) {
  if ($env:KANTO_GEAR_PREVIEW_GEN -eq "1") {
    $overworldSource = Join-Path $env:APPDATA `
      "pokemon-love2d\red\assets\generated\sprites"
    $overworldFiles = @{ player = "red.png"; trainer1 = "biker.png";
      trainer2 = "beauty.png"; trainer3 = "cooltrainer_f.png" }
  } else {
    foreach ($game in @("gold", "crystal", "silver")) {
      $candidate = Join-Path $env:APPDATA `
        "pokemon-love2d\$game\assets\generated\sprites"
      if (Test-Path -LiteralPath (Join-Path $candidate "chris.png")) {
        $overworldSource = $candidate
        break
      }
    }
    $overworldFiles = @{ player = "chris.png"; trainer1 = "teacher.png";
      trainer2 = "psychic.png"; trainer3 = "twin.png" }
  }
  foreach ($entry in $overworldFiles.GetEnumerator()) {
    if (-not $overworldSource -or
        -not (Test-Path -LiteralPath (Join-Path $overworldSource $entry.Value))) {
      throw "Missing locally extracted Gen $env:KANTO_GEAR_PREVIEW_GEN overworld sprite: $($entry.Value)"
    }
  }
}
if (-not $Output) { $Output = Join-Path $PSScriptRoot "out\party.png" }
$Output = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path (Split-Path $Output) -Force | Out-Null
$rendered = Join-Path (Split-Path $Output) `
  ("preview-" + [Guid]::NewGuid().ToString("N") + ".png")
$runtime = Join-Path $env:TEMP "kg-hgss-preview"
New-Item -ItemType Directory -Path (Join-Path $runtime "local") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runtime "local\overworld") `
  -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "main.lua") `
  -Destination (Join-Path $runtime "main.lua") -Force
$sourceImages | Copy-Item -Destination (Join-Path $runtime "local") -Force
foreach ($entry in $overworldFiles.GetEnumerator()) {
  Copy-Item -LiteralPath (Join-Path $overworldSource $entry.Value) `
    -Destination (Join-Path $runtime "local\overworld\$($entry.Key).png") -Force
}
$env:KANTO_GEAR_ROOT = $root.Replace("\", "/")
$env:KANTO_GEAR_PREVIEW_OUT = $rendered.Replace("\", "/")
$process = Start-Process -FilePath $love -ArgumentList @($runtime) `
  -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(10000)) {
  Stop-Process -Id $process.Id
  throw "Preview renderer timed out."
}
if ($process.ExitCode) { exit $process.ExitCode }
if (-not (Test-Path -LiteralPath $rendered)) { throw "Preview was not created." }
Move-Item -LiteralPath $rendered -Destination $Output -Force
Write-Output $Output
