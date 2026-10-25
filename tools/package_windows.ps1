param(
    [string]$Godot = 'Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
Set-Content -LiteralPath (Join-Path $buildDirectory '.gdignore') -Value ''
$godotConsole = (Get-Command $Godot).Source
$godotRuntime = $godotConsole -replace '_console\.exe$', '.exe'
if (!(Test-Path -LiteralPath $godotRuntime)) { throw 'Matching Godot runtime was not found beside the console executable.' }
$pendingPack = Join-Path $buildDirectory 'Hero.pending.pck'
& $godotConsole --headless --path $projectRoot --export-pack 'Windows Desktop' $pendingPack
if ($LASTEXITCODE -ne 0) { throw 'Godot pack export failed.' }
if (!(Test-Path -LiteralPath $pendingPack) -or (Get-Item -LiteralPath $pendingPack).Length -lt 1024) { throw 'Godot did not produce a valid resource pack.' }
Move-Item -LiteralPath $pendingPack -Destination (Join-Path $buildDirectory 'Hero.pck') -Force
# The installed official engine can launch a sidecar PCK without export templates.
Copy-Item -LiteralPath $godotRuntime -Destination (Join-Path $buildDirectory 'Hero.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'CREDITS.md') -Destination $buildDirectory -Force
$attributionDirectory = Join-Path $buildDirectory 'assets\provided'
New-Item -ItemType Directory -Force -Path $attributionDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\provided\ATTRIBUTION.md') -Destination $attributionDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\provided\source_manifest.json') -Destination $attributionDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'PLATFORMS.md') -Destination $buildDirectory -Force
New-Item -ItemType Directory -Force -Path (Join-Path $buildDirectory 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\OFL.txt') -Destination (Join-Path $buildDirectory 'assets\OFL.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\OFL.txt') -Destination (Join-Path $buildDirectory 'FONT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'License.txt') -Destination (Join-Path $buildDirectory 'ANIMATION-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'read me .txt') -Destination (Join-Path $buildDirectory 'CHARACTER-LICENSE.txt') -Force
& $godotConsole --headless --path $projectRoot --script tools/write_engine_licenses.gd
if ($LASTEXITCODE -ne 0) { throw 'Writing engine license notices failed.' }
Write-Output "Portable build ready: $buildDirectory\Hero.exe"
