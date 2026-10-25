# Build from a generated project so phone texture limits never alter source art
# or desktop import settings. The stage contains only runtime dependencies.
function New-AndroidExportStage {
    param([string]$ProjectRoot, [string]$BuildDirectory, [int]$TextureLimit = 1024,
        [ValidateSet('arm64-v8a', 'x86_64')][string[]]$Architectures = @('arm64-v8a'))
    $ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory).TrimEnd('\')
    $stageRoot = [IO.Path]::GetFullPath((Join-Path $BuildDirectory 'staging'))
    if ((Split-Path -Parent $stageRoot) -ne $BuildDirectory -or $stageRoot -eq $ProjectRoot) { throw 'Android staging must be a child of the requested build directory.' }
    if (Test-Path -LiteralPath $stageRoot) {
        $existingStage = Get-Item -LiteralPath $stageRoot -Force
        # OneDrive marks ordinary cloud-backed directories as reparse points.
        # Reject actual links/junctions, while allowing a normal synced folder.
        if ($existingStage.LinkType -or ($existingStage.Target | Where-Object { $_ })) { throw 'Refusing to replace a linked staging directory.' }
    }
    # Reuse the import cache between repair builds. Explicit export roots keep
    # obsolete stage files out of the APK, so no recursive deletion is needed.
    New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
    $manifest = Get-Content -LiteralPath (Join-Path $BuildDirectory 'resource-manifest.json') -Raw | ConvertFrom-Json
    $resources = @($manifest.dependencies) + @('res://project.godot', 'res://export_presets.cfg', 'res://assets/hero_192.png', 'res://assets/hero_adaptive_foreground.png', 'res://assets/hero_adaptive_background.png', 'res://assets/OFL.txt', 'res://License.txt', 'res://read me .txt', 'res://CREDITS.md', 'res://assets/provided/ATTRIBUTION.md')
    foreach ($resource in ($resources | Select-Object -Unique)) {
        if (!$resource.StartsWith('res://')) { throw "Invalid Android resource: $resource" }
        $relative = $resource.Substring(6).Replace('/', '\')
        $source = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $relative))
        $destination = [IO.Path]::GetFullPath((Join-Path $stageRoot $relative))
        if (!$source.StartsWith($ProjectRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or !$destination.StartsWith($stageRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Resource path escaped the Android staging directories.' }
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing Android stage resource: $resource" }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        if (!(Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
        foreach ($suffix in @('.import', '.uid')) {
            if (!(Test-Path -LiteralPath ($source + $suffix))) { continue }
            if ($suffix -eq '.import' -and $resource -match '^res://assets/(provided|buildings)/.+\.(png|jpg|jpeg|webp)$') { continue }
            if (!(Test-Path -LiteralPath ($destination + $suffix)) -or (Get-FileHash -LiteralPath ($source + $suffix)).Hash -ne (Get-FileHash -LiteralPath ($destination + $suffix)).Hash) {
                Copy-Item -LiteralPath ($source + $suffix) -Destination ($destination + $suffix) -Force
            }
        }
        if ($resource -match '^res://assets/(provided|buildings)/.+\.(png|jpg|jpeg|webp)$') {
            $importPath = $destination + '.import'
            if (!(Test-Path -LiteralPath ($source + '.import'))) { throw "Material texture has no import settings: $resource" }
            $settings = Get-Content -LiteralPath ($source + '.import') -Raw
            $settings = $settings -replace '(?m)^compress/mode=\d+', 'compress/mode=2'
            $settings = $settings -replace '(?m)^process/size_limit=\d+', "process/size_limit=$TextureLimit"
            $settings = $settings -replace '(?m)^mipmaps/generate=\w+', 'mipmaps/generate=true'
            if (!(Test-Path -LiteralPath $importPath) -or [IO.File]::ReadAllText($importPath) -ne $settings) {
                [IO.File]::WriteAllText($importPath, $settings, [Text.UTF8Encoding]::new($false))
            }
        }
    }
    Copy-Item -LiteralPath (Join-Path $ProjectRoot 'build\ENGINE-LICENSES.txt') -Destination (Join-Path $stageRoot 'ENGINE-LICENSES.txt')
    $projectPath = Join-Path $stageRoot 'project.godot'
    $project = Get-Content -LiteralPath $projectPath -Raw
    $project = $project -replace '(?m)^enabled=PackedStringArray\([^\r\n]*\)', 'enabled=PackedStringArray()'
    $project = $project -replace '(?m)^textures/vram_compression/import_s3tc_bptc=.*\r?\n', ''
    $project = $project.Replace('[rendering]', "[rendering]`r`n`r`ntextures/vram_compression/import_s3tc_bptc=false")
    [IO.File]::WriteAllText($projectPath, $project, [Text.UTF8Encoding]::new($false))
    $presetPath = Join-Path $stageRoot 'export_presets.cfg'
    $presets = Get-Content -LiteralPath $presetPath -Raw
    # Packaging repairs the manifest and aligns the APK before signing it
    # once with apksigner. Godot's preliminary signature is unnecessary and
    # would require launching keytool.exe with the password on its command line.
    $presets = $presets -replace '(?m)^package/signed=\w+', 'package/signed=false'
    foreach ($architecture in @('armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64')) {
        $enabled = if ($Architectures -contains $architecture) { 'true' } else { 'false' }
        $presets = $presets -replace ('(?m)^architectures/' + [regex]::Escape($architecture) + '=\w+'), ('architectures/' + $architecture + '=' + $enabled)
    }
    [IO.File]::WriteAllText($presetPath, $presets, [Text.UTF8Encoding]::new($false))
    return $stageRoot
}
