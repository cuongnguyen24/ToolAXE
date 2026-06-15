param(
    [Parameter(Mandatory = $true)]
    [string]$MediaRoot
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MediaRoot)) {
    exit 1
}

$setup = Get-ChildItem -LiteralPath $MediaRoot -Recurse -Filter setup.exe -File -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($setup) {
    Write-Output $setup.FullName
    exit 0
}

$iso = Get-ChildItem -LiteralPath $MediaRoot -Recurse -Filter *.iso -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $iso) {
    exit 2
}

$image = Mount-DiskImage -ImagePath $iso.FullName -PassThru
Start-Sleep -Seconds 2

$volume = $image | Get-Volume | Select-Object -First 1
if (-not $volume -or -not $volume.DriveLetter) {
    exit 3
}

$mountedSetup = Join-Path ($volume.DriveLetter + ":\") "setup.exe"
if (-not (Test-Path -LiteralPath $mountedSetup)) {
    exit 4
}

Write-Output $mountedSetup
exit 0
