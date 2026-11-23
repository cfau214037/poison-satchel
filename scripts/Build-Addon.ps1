param(
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'PoisonSatchel'
$toc = Join-Path $addon 'PoisonSatchel_Forever.toc'
$version = Select-String -LiteralPath $toc -Pattern '^## Version:\s*(\d+\.\d+\.\d+)\s*$'
if (@($version).Count -ne 1) {
    throw 'Expected exactly one version in the TOC in X.Y.Z format.'
}

$expectedTag = 'v' + $version.Matches[0].Groups[1].Value
if ($Tag -and $Tag -cne $expectedTag) {
    throw "Tag $Tag does not match TOC version $expectedTag."
}

$dist = Join-Path $root 'dist'
New-Item -Path $dist -ItemType Directory -Force | Out-Null
$archivePath = Join-Path $dist "PoisonSatchel-$expectedTag.zip"
$stream = [IO.File]::Create($archivePath)
try {
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $addon -Recurse -File | Sort-Object FullName) {
            $relativePath = [IO.Path]::GetRelativePath($addon, $file.FullName).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, "PoisonSatchel/$relativePath"
            ) | Out-Null
        }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, (Join-Path $root 'LICENSE'), 'PoisonSatchel/LICENSE'
        ) | Out-Null
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $stream.Dispose()
}

$archivePath
