param(
    [string]$JavaHome = '',
    [string]$AndroidHome = '',
    [string]$Godot = 'Godot_v4.7.2-stable_win64_console.exe',
    [ValidateSet(512, 1024, 2048)][int]$TextureLimit = 1024,
    [string]$BuildDirectory = '',
    [ValidatePattern('^[^\\/:*?"<>|]+\.apk$')][string]$ApkName = 'Hero-repaired.apk',
    [ValidateSet('arm64-v8a', 'x86_64')][string[]]$Architectures = @('arm64-v8a')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$BuildDirectory) { $BuildDirectory = Join-Path $projectRoot 'build\android' }
$buildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$Architectures = @($Architectures | Select-Object -Unique)
if (!$Architectures.Count) { throw 'At least one Android architecture is required.' }
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'build\.gdignore') -Value ''

function Protect-CommandOutput {
    param([string]$Content)
    # Godot can echo its keytool command, including the supplied password,
    # when Windows cannot launch that child process. Redact before saving.
    foreach ($secretName in @('RELIC_SIGNING_PASSWORD', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')) {
        $secretValue = [Environment]::GetEnvironmentVariable($secretName, 'Process')
        if ($secretValue) { $Content = $Content.Replace($secretValue, '[REDACTED]') }
    }
    $passwordArgument = '(?i)(--?(?:storepass|keypass|ks-pass|key-pass)(?:\s+|=))(?:"[^"]*"|''[^'']*''|[^\s]+)'
    return [regex]::Replace($Content, $passwordArgument, '$1[REDACTED]')
}

function Invoke-LoggedCommand {
    param([string]$Executable, [string[]]$Arguments, [string]$Log, [string]$Failure, [switch]$AllowEditorPreferenceErrors, [switch]$AllowEditorShutdownLeaks)
    # Capture native stderr directly: Windows PowerShell formats stderr as
    # ErrorRecords (wrapping lines and adding duplicate ERROR text), which is
    # unsuitable for reliable build diagnostics.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $quotedArguments = foreach ($argument in $Arguments) {
        $escaped = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }
    $startInfo.Arguments = $quotedArguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (!$process.Start()) { throw "Could not start $Executable" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $commandExit = $process.ExitCode
        $safeOutput = Protect-CommandOutput -Content ($stdoutTask.Result + $stderrTask.Result)
        [IO.File]::WriteAllText($Log, $safeOutput, [Text.UTF8Encoding]::new($false))
    } finally {
        $process.Dispose()
    }
    if ($commandExit -ne 0) { throw "$Failure See $Log." }
    $errorLines = @(Select-String -LiteralPath $Log -Pattern 'SCRIPT ERROR:|ERROR:' | ForEach-Object Line)
    if ($AllowEditorPreferenceErrors) {
        # This workstation's saved editor layout invokes a broken VS Code
        # shortcut while opening script tabs. It is unrelated to importing or
        # compiling resources; preserve the user's global editor preference.
        $errorLines = @($errorLines | Where-Object { $_ -notmatch 'Could not create child process:.*Visual Studio Code\.lnk|Couldn.t open external text editor, falling back to the internal editor' })
    }
    if ($AllowEditorShutdownLeaks) {
        # A SceneTree script used solely to configure EditorSettings exits the
        # editor without its usual main loop. Do not mistake its teardown
        # diagnostics for game/import failures. No runtime check uses this.
        $errorLines = @($errorLines | Where-Object { $_ -notmatch 'ERROR: \d+ RID allocations of type .* were leaked at exit\.|ERROR: \d+ resources still in use at exit' })
    }
    if ($errorLines.Count -gt 0) { throw "$Failure See $Log." }
}

$godotExecutable = (Get-Command $Godot -ErrorAction Stop).Source
if (!$AndroidHome) {
    $AndroidHome = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
}
if (!(Test-Path -LiteralPath (Join-Path $AndroidHome 'platform-tools\adb.exe'))) {
    throw 'Android SDK platform-tools are missing. Supply -AndroidHome with an installed Android SDK.'
}

if (!$JavaHome) {
    $javaCandidates = @($env:JAVA_HOME, 'C:\Program Files\Android\Android Studio\jbr')
    $javaCandidates += @(Get-ChildItem -Path 'C:\Program Files\Java\jdk*','C:\Program Files\Microsoft\jdk*','C:\Program Files\Eclipse Adoptium\jdk*' -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
    # The VS Code Java extension bundles a complete JDK on Windows.
    $javaCandidates += @(Get-ChildItem -Path (Join-Path $env:USERPROFILE '.vscode\extensions\redhat.java-*\jre\*') -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object FullName)
    foreach ($candidate in $javaCandidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\javac.exe')) -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\keytool.exe'))) {
            $JavaHome = $candidate
            break
        }
    }
}
if (!$JavaHome -or !(Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe')) -or !(Test-Path -LiteralPath (Join-Path $JavaHome 'bin\keytool.exe'))) {
    throw 'A Java 17+ JDK is required. Supply its installation directory with -JavaHome.'
}
$javaExecutable = Join-Path $JavaHome 'bin\java.exe'
$javaVersionLog = Join-Path $buildDirectory 'java-version.log'
Invoke-LoggedCommand -Executable $javaExecutable -Arguments @('-version') -Log $javaVersionLog -Failure 'Java could not run.'
$javaVersionText = Get-Content -LiteralPath $javaVersionLog -Raw
if ($javaVersionText -notmatch 'version "(\d+)' -or [int]$Matches[1] -lt 17) { throw 'Android packaging requires Java 17 or newer.' }

$buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidHome 'build-tools') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'lib\apksigner.jar')) } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$buildTools) { throw 'Android SDK build-tools with apksigner, aapt2 and zipalign are required.' }
$apkSigner = Join-Path $buildTools.FullName 'lib\apksigner.jar'
$aapt = Join-Path $buildTools.FullName 'aapt2.exe'
$zipalign = Join-Path $buildTools.FullName 'zipalign.exe'
foreach ($toolPath in @($aapt, $zipalign)) {
    if (!(Test-Path -LiteralPath $toolPath)) { throw "Android build tool is missing: $toolPath" }
}

$signingDirectory = Join-Path $env:LOCALAPPDATA 'RELIC\signing'
$keyPath = Join-Path $signingDirectory 'relic-release.keystore'
$passwordPath = Join-Path $signingDirectory 'password.dpapi'
$certificatePath = Join-Path $signingDirectory 'release-certificate.sha256'
if ((Test-Path -LiteralPath $keyPath) -xor (Test-Path -LiteralPath $passwordPath)) {
    throw 'Signing files are incomplete. Restore the existing signing material; do not replace the key.'
}
if ((Test-Path -LiteralPath $certificatePath) -and !(Test-Path -LiteralPath $keyPath)) {
    throw 'A previous signing certificate exists but its private key is missing. Restore that key before rebuilding.'
}

$environmentNames = @('RELIC_SIGNING_PASSWORD', 'RELIC_JAVA_HOME', 'RELIC_ANDROID_HOME', 'JAVA_HOME', 'GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$apkStem = [IO.Path]::GetFileNameWithoutExtension($ApkName)
$pendingApk = Join-Path $buildDirectory ($apkStem + '.pending.apk')
$alignedApk = Join-Path $buildDirectory ($apkStem + '.aligned.apk')
$finalApk = Join-Path $buildDirectory $ApkName
$createdSigningKey = $false
try {
    if (!(Test-Path -LiteralPath $keyPath)) {
        New-Item -ItemType Directory -Force -Path $signingDirectory | Out-Null
        $randomBytes = New-Object byte[] 32
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
        $secret = [Convert]::ToBase64String($randomBytes)
        $env:RELIC_SIGNING_PASSWORD = $secret
        $pendingKey = Join-Path $signingDirectory 'relic-release.pending.keystore'
        $pendingPassword = Join-Path $signingDirectory 'password.pending.dpapi'
        if ((Test-Path -LiteralPath $pendingKey) -or (Test-Path -LiteralPath $pendingPassword)) {
            throw 'Unfinished signing material exists. Inspect it before creating a new release key.'
        }
        $secret | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $pendingPassword
        Invoke-LoggedCommand -Executable (Join-Path $JavaHome 'bin\keytool.exe') -Arguments @('-genkeypair', '-keystore', $pendingKey, '-storetype', 'JKS', '-storepass:env', 'RELIC_SIGNING_PASSWORD', '-keypass:env', 'RELIC_SIGNING_PASSWORD', '-alias', 'relic', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000', '-dname', 'CN=Hero, O=Hero') -Log (Join-Path $buildDirectory 'keygen.log') -Failure 'APK signing key generation failed.'
        Move-Item -LiteralPath $pendingKey -Destination $keyPath
        Move-Item -LiteralPath $pendingPassword -Destination $passwordPath
        $createdSigningKey = $true
    } else {
        $secure = Get-Content -LiteralPath $passwordPath | ConvertTo-SecureString
        $secret = [Net.NetworkCredential]::new('', $secure).Password
    }
    $env:RELIC_JAVA_HOME = $JavaHome
    $env:RELIC_ANDROID_HOME = $AndroidHome
    $env:JAVA_HOME = $JavaHome
    # Godot only creates the unsigned payload. Keep signing credentials out
    # of its environment; the existing key is used by apksigner below.
    foreach ($name in @('RELIC_SIGNING_PASSWORD', 'GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')) {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }

    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--path', $projectRoot, '--script', 'tools/export_mobile_icons.gd') -Log (Join-Path $buildDirectory 'icons.log') -Failure 'Android icon generation failed.'
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--path', $projectRoot, '--script', 'tools/write_engine_licenses.gd') -Log (Join-Path $buildDirectory 'licenses.log') -Failure 'Engine license generation failed.'
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--editor', '--path', $projectRoot, '--script', 'tools/configure_android.gd') -Log (Join-Path $buildDirectory 'configure.log') -Failure 'Android toolchain configuration failed.' -AllowEditorPreferenceErrors -AllowEditorShutdownLeaks
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--editor', '--path', $projectRoot, '--import', '--quit') -Log (Join-Path $buildDirectory 'import.log') -Failure 'Godot resource import failed.' -AllowEditorPreferenceErrors
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--path', $projectRoot, '--script', 'tools/prepare_android_resources.gd') -Log (Join-Path $buildDirectory 'resources.log') -Failure 'Android resource selection failed.'
    . (Join-Path $PSScriptRoot 'stage_android_project.ps1')
    $sourceManifest = Join-Path $projectRoot 'build\android\resource-manifest.json'
    $outputManifest = Join-Path $buildDirectory 'resource-manifest.json'
    if ([IO.Path]::GetFullPath($sourceManifest) -ne [IO.Path]::GetFullPath($outputManifest)) {
        Copy-Item -LiteralPath $sourceManifest -Destination $outputManifest -Force
    }
    $stageRoot = New-AndroidExportStage -ProjectRoot $projectRoot -BuildDirectory $buildDirectory -TextureLimit $TextureLimit -Architectures $Architectures
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--editor', '--path', $stageRoot, '--import', '--quit') -Log (Join-Path $buildDirectory 'mobile-import.log') -Failure 'Android texture/resource import failed.'
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--path', $stageRoot, '--export-release', 'Android', $pendingApk) -Log (Join-Path $buildDirectory 'export.log') -Failure 'Android export failed.'
    if (!(Test-Path -LiteralPath $pendingApk) -or (Get-Item -LiteralPath $pendingApk).Length -lt 1048576) { throw 'Godot did not produce a valid APK.' }

    . (Join-Path $PSScriptRoot 'repair_android_manifest.ps1')
    Repair-AndroidProviderAuthority -Apk $pendingApk
    Invoke-LoggedCommand -Executable $zipalign -Arguments @('-f', '-P', '16', '4', $pendingApk, $alignedApk) -Log (Join-Path $buildDirectory 'align.log') -Failure 'APK alignment failed.'
    $env:RELIC_SIGNING_PASSWORD = $secret
    try {
        Invoke-LoggedCommand -Executable $javaExecutable -Arguments @('-jar', $apkSigner, 'sign', '--ks', $keyPath, '--ks-pass', 'env:RELIC_SIGNING_PASSWORD', '--key-pass', 'env:RELIC_SIGNING_PASSWORD', '--ks-key-alias', 'relic', '--v4-signing-enabled', 'false', $alignedApk) -Log (Join-Path $buildDirectory 'sign.log') -Failure 'APK signing after manifest repair failed.'
    } finally {
        [Environment]::SetEnvironmentVariable('RELIC_SIGNING_PASSWORD', $null, 'Process')
    }
    Move-Item -LiteralPath $alignedApk -Destination $pendingApk -Force
    if (Test-Path -LiteralPath ($pendingApk + '.idsig')) { Remove-Item -LiteralPath ($pendingApk + '.idsig') }

    $signatureLog = Join-Path $buildDirectory 'signature.log'
    Invoke-LoggedCommand -Executable $javaExecutable -Arguments @('-jar', $apkSigner, 'verify', '--verbose', '--print-certs', $pendingApk) -Log $signatureLog -Failure 'APK signature validation failed.'
    Invoke-LoggedCommand -Executable $zipalign -Arguments @('-c', '-P', '16', '-v', '4', $pendingApk) -Log (Join-Path $buildDirectory 'alignment.log') -Failure 'APK 16 KB page alignment validation failed.'
    $manifestLog = Join-Path $buildDirectory 'manifest.log'
    Invoke-LoggedCommand -Executable $aapt -Arguments @('dump', 'badging', $pendingApk) -Log $manifestLog -Failure 'APK manifest inspection failed.'
    $manifest = Get-Content -LiteralPath $manifestLog -Raw
    if ($manifest -notmatch "package: name='com.northstar.relicarena'" -or $manifest -notmatch "application-label:'Hero'") { throw 'The APK package identity is incorrect.' }
    $xmlLog = Join-Path $buildDirectory 'manifest-xml.log'
    Invoke-LoggedCommand -Executable $aapt -Arguments @('dump', 'xmltree', $pendingApk, '--file', 'AndroidManifest.xml') -Log $xmlLog -Failure 'APK launcher manifest inspection failed.'
    $xmlManifest = Get-Content -LiteralPath $xmlLog -Raw
    # aapt2 badging omits isGame on this template, so inspect actual XML values.
    # Android's appCategory GAME value is 0 (Godot's export UI index is 2).
    if ($xmlManifest -notmatch 'android:isGame\([^)]*\)=true' -or $xmlManifest -notmatch 'android:appCategory\([^)]*\)=0') { throw 'The APK Android game category is incorrect.' }
    # Godot 4.7 uses an exported activity alias; aapt badging omits these.
    if ($xmlManifest -notmatch 'GodotAppLauncher' -or $xmlManifest -notmatch 'android.intent.category.LAUNCHER' -or $xmlManifest -notmatch 'com.northstar.relicarena.initprovider') { throw 'APK launcher alias or AndroidX provider authority is incorrect.' }
    if ($manifest -notmatch '(?m)^native-code: (.+)$') { throw 'The APK has no native architectures.' }
    $actualArchitectures = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    if (@(Compare-Object ($Architectures | Sort-Object) ($actualArchitectures | Sort-Object)).Count) { throw 'The APK native architectures differ from the requested architectures.' }
    if ($manifest -match 'uses-permission:') { throw 'Unexpected Android permission in the offline game APK. Review manifest.log.' }
    # Load the exact exported resource payload in an isolated Godot process.
    # No development files can silently satisfy a missing packaged dependency.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $payloadZip = Join-Path $buildDirectory 'runtime-check.zip'
    if (Test-Path -LiteralPath $payloadZip) { Remove-Item -LiteralPath $payloadZip }
    $archive = [IO.Compression.ZipFile]::OpenRead($pendingApk)
    $payload = [IO.Compression.ZipFile]::Open($payloadZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($architecture in $Architectures) {
        $nativeEntry = $archive.GetEntry('lib/' + $architecture + '/libgodot_android.so')
        if (!$nativeEntry) { throw "The $architecture Godot library is missing." }
        $nativeStream = $nativeEntry.Open()
        $nativeMemory = [IO.MemoryStream]::new()
        try { $nativeStream.CopyTo($nativeMemory); $nativeBytes = $nativeMemory.ToArray() } finally { $nativeStream.Dispose(); $nativeMemory.Dispose() }
        if ($nativeBytes[4] -ne 2 -or $nativeBytes[5] -ne 1) { throw 'Expected a 64-bit little-endian Android ELF library.' }
        $programOffset = [BitConverter]::ToUInt64($nativeBytes, 32)
        $programSize = [BitConverter]::ToUInt16($nativeBytes, 54)
        $programCount = [BitConverter]::ToUInt16($nativeBytes, 56)
        $loadSegments = 0
        for ($index = 0; $index -lt $programCount; $index++) {
            $segmentOffset = $programOffset + $index * $programSize
            if ([BitConverter]::ToUInt32($nativeBytes, $segmentOffset) -eq 1) {
                $loadSegments++
                if ([BitConverter]::ToUInt64($nativeBytes, $segmentOffset + 48) -lt 16384) { throw 'Android native library does not support 16 KB memory pages.' }
            }
        }
        if ($loadSegments -lt 1) { throw 'Android native library has no loadable ELF segments.' }
        $nativeBytes = $null
        }
        foreach ($notice in @('CREDITS.md', 'ENGINE-LICENSES.txt', 'License.txt', 'assets/OFL.txt', 'assets/provided/ATTRIBUTION.md')) {
            if (!$archive.GetEntry('assets/' + $notice)) { throw "License notice missing from APK: $notice" }
        }
        foreach ($entry in $archive.Entries) {
            if (!$entry.FullName.StartsWith('assets/') -or $entry.FullName.EndsWith('/')) { continue }
            $resourcePath = $entry.FullName.Substring(7)
            if ($resourcePath -match '^(art|backups|build|Godot|tests|tools|addons|textures)/') { throw "Unexpected authoring file in Android APK: $resourcePath" }
            $copy = $payload.CreateEntry($resourcePath, [IO.Compression.CompressionLevel]::NoCompression)
            $sourceStream = $entry.Open()
            $targetStream = $copy.Open()
            try { $sourceStream.CopyTo($targetStream) } finally { $sourceStream.Dispose(); $targetStream.Dispose() }
        }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($payload, (Join-Path $PSScriptRoot 'check_android_payload.gd'), '__android_validation.gd') | Out-Null
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($payload, (Join-Path $buildDirectory 'resource-manifest.json'), '__android_resources.json') | Out-Null
    } finally { $payload.Dispose(); $archive.Dispose() }
    $validationDirectory = Join-Path $buildDirectory 'payload-validation'
    New-Item -ItemType Directory -Force -Path $validationDirectory | Out-Null
    Invoke-LoggedCommand -Executable $godotExecutable -Arguments @('--headless', '--path', $validationDirectory, '--main-pack', $payloadZip, '--script', 'res://__android_validation.gd') -Log (Join-Path $buildDirectory 'payload-validation.log') -Failure 'Android exported-resource validation failed.'
    $signature = Get-Content -LiteralPath $signatureLog -Raw
    if ($signature -notmatch 'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)') { throw 'The APK signing certificate could not be read.' }
    $certificate = $Matches[1].ToUpperInvariant()
    if ((Test-Path -LiteralPath $certificatePath) -and (Get-Content -LiteralPath $certificatePath -Raw).Trim() -ne $certificate) { throw 'The release signing certificate changed. The previous APK has been kept.' }
    Set-Content -LiteralPath $certificatePath -Value $certificate
    $manifest -match "versionCode='(\d+)' versionName='([^']+)'" | Out-Null
    $versionCode = [int]$Matches[1]
    $versionName = $Matches[2]
    Move-Item -LiteralPath $pendingApk -Destination $finalApk -Force
    $hash = (Get-FileHash -LiteralPath $finalApk -Algorithm SHA256).Hash
    Set-Content -LiteralPath (Join-Path $buildDirectory ($ApkName + '.sha256')) -Value "$hash  $ApkName"
    $verification = [ordered]@{
        file = $ApkName; package = 'com.northstar.relicarena'; version = $versionName; version_code = $versionCode
        bytes = (Get-Item -LiteralPath $finalApk).Length; sha256 = $hash; certificate_sha256 = $certificate
        architectures = $Architectures; min_android_api = 24; target_android_api = 36; gles = '3.0'
        signed_release = $true; alignment_16kb = $true; elf_16kb_pages = $true; exported_resources_validated = $true; runtime_on_device_tested = $false
        material_texture_max_size = $TextureLimit; texture_format = 'ETC2'; source_assets_modified = $false
        new_signing_key_created = $createdSigningKey; generated_utc = [DateTime]::UtcNow.ToString('o')
    }
    $verification | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buildDirectory 'verification.json')
    Copy-Item -LiteralPath (Join-Path $projectRoot 'CREDITS.md') -Destination $buildDirectory -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\provided\ATTRIBUTION.md') -Destination (Join-Path $buildDirectory 'MODEL-ATTRIBUTION.md') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'build\ENGINE-LICENSES.txt') -Destination $buildDirectory -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\OFL.txt') -Destination (Join-Path $buildDirectory 'FONT-LICENSE.txt') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'License.txt') -Destination (Join-Path $buildDirectory 'ANIMATION-LICENSE.txt') -Force
    Write-Output "Signed APK ready: $finalApk"
    Write-Output "SHA-256: $hash"
    Write-Output "Signing material is stored outside the project: $signingDirectory"
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    $secret = $null
    $secure = $null
}
