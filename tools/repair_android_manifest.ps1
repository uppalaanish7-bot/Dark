# Godot 4.7.2's non-Gradle exporter rewrites every provider authority to
# <package>.fileprovider, including AndroidX Startup. Restore a unique authority
# without changing any binary XML offsets. Only the temporary APK is modified;
# package_android.ps1 realigns and signs it again afterward.
function Repair-AndroidProviderAuthority {
    param([Parameter(Mandatory=$true)][string]$Apk)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::Open($Apk, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $archive.GetEntry('AndroidManifest.xml')
        $stream = $entry.Open()
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
        $data = $memory.ToArray()
        $memory.Dispose()
        if ([BitConverter]::ToUInt16($data, 0) -ne 3) { throw 'Expected binary Android XML.' }
        $offset = 8
        $stringPositions = @()
        $strings = @()
        $providers = @()
        while ($offset -lt $data.Length) {
            $kind = [BitConverter]::ToUInt16($data, $offset)
            $headerSize = [BitConverter]::ToUInt16($data, $offset + 2)
            $chunkSize = [BitConverter]::ToUInt32($data, $offset + 4)
            if ($chunkSize -lt $headerSize -or $offset + $chunkSize -gt $data.Length) { throw 'Invalid Android manifest chunk.' }
            if ($kind -eq 1) {
                $count = [BitConverter]::ToUInt32($data, $offset + 8)
                $flags = [BitConverter]::ToUInt32($data, $offset + 16)
                $start = [BitConverter]::ToUInt32($data, $offset + 20)
                if ($flags -band 0x100) { throw 'Expected the UTF-16 string pool written by Godot.' }
                for ($index = 0; $index -lt $count; $index++) {
                    $position = $offset + $start + [BitConverter]::ToUInt32($data, $offset + $headerSize + $index * 4)
                    $length = [BitConverter]::ToUInt16($data, $position)
                    if ($length -band 0x8000) { throw 'Unexpected long Android manifest string.' }
                    $strings += [Text.Encoding]::Unicode.GetString($data, $position + 2, $length * 2)
                    $stringPositions += $position + 2
                }
            } elseif ($kind -eq 0x102 -and $strings[[BitConverter]::ToUInt32($data, $offset + 20)] -eq 'provider') {
                $attributeStart = [BitConverter]::ToUInt16($data, $offset + 24)
                $attributeSize = [BitConverter]::ToUInt16($data, $offset + 26)
                $attributeCount = [BitConverter]::ToUInt16($data, $offset + 28)
                $provider = @{}
                for ($index = 0; $index -lt $attributeCount; $index++) {
                    $attribute = $offset + 16 + $attributeStart + $index * $attributeSize
                    $name = $strings[[BitConverter]::ToUInt32($data, $attribute + 4)]
                    if ($name -in @('name', 'authorities')) {
                        if ($data[$attribute + 15] -ne 3) { throw 'Expected a string provider attribute.' }
                        $valueIndex = [BitConverter]::ToUInt32($data, $attribute + 16)
                        $provider[$name] = $strings[$valueIndex]
                        $provider[$name + '_index'] = $valueIndex
                    }
                }
                $providers += $provider
            }
            $offset += $chunkSize
        }
        $startup = $providers | Where-Object { $_.name -eq 'androidx.startup.InitializationProvider' }
        $fileProvider = $providers | Where-Object { $_.name -eq 'androidx.core.content.FileProvider' }
        if (!$startup -or !$fileProvider) { throw 'Expected Godot template providers were not found.' }
        if ($startup.authorities -ne $fileProvider.authorities) { return }
        if ($startup.authorities_index -eq $fileProvider.authorities_index) { throw 'Cannot repair a shared provider authority string.' }
        $newAuthority = $startup.authorities -replace '\.fileprovider$', '.initprovider'
        if ($newAuthority -eq $startup.authorities -or $newAuthority.Length -ne $startup.authorities.Length) { throw 'Unexpected provider authority format.' }
        $replacement = [Text.Encoding]::Unicode.GetBytes($newAuthority)
        [Array]::Copy($replacement, 0, $data, $stringPositions[$startup.authorities_index], $replacement.Length)
        $entry.Delete()
        $entry = $archive.CreateEntry('AndroidManifest.xml', [IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try { $stream.Write($data, 0, $data.Length) } finally { $stream.Dispose() }
        Write-Output "Repaired AndroidX provider authority: $newAuthority"
    } finally { $archive.Dispose() }
}
