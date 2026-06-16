param(
    [Parameter(Mandatory = $true)]
    [string]$MediaRoot
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MediaRoot)) {
    exit 1
}

$candidates = @(
    "vs_setup.exe",
    "SSMS-Setup-ENU.exe",
    "vs_SSMS.exe",
    "vs_ssms.exe"
)

foreach ($name in $candidates) {
    $match = Get-ChildItem -LiteralPath $MediaRoot -Recurse -Filter $name -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($match) {
        Write-Output $match.FullName
        exit 0
    }
}

exit 2
