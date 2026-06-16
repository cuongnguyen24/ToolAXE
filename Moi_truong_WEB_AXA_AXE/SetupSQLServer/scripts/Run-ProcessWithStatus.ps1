param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string]$ArgumentString = "",

    [string]$StatusMessage = "Dang xu ly",

    [string]$LogPath = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $FilePath)) {
    throw "File not found: $FilePath"
}

function Write-SetupLog {
    param([string]$Message)

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        Add-Content -LiteralPath $LogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    }
}

Write-Host "[INFO] $StatusMessage"
Write-Host "[INFO] File: $FilePath"
Write-SetupLog "START: $StatusMessage"
Write-SetupLog "FilePath: $FilePath"
Write-SetupLog "Arguments: $ArgumentString"

$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $FilePath
$processInfo.Arguments = $ArgumentString
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo

[void]$process.Start()
$start = Get-Date

while (-not $process.WaitForExit(15000)) {
    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    Write-Host ("[DANG CHAY] {0} - da chay {1} giay. Vui long cho..." -f $StatusMessage, $elapsed)
    Write-SetupLog ("RUNNING: {0}, elapsed={1}s, pid={2}" -f $StatusMessage, $elapsed, $process.Id)
}

$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$exitCode = $process.ExitCode

if ($null -eq $exitCode) {
    $exitCode = 1
}

Write-Host "[INFO] Hoan tat tien trinh. ExitCode=$exitCode"
Write-SetupLog "END: $StatusMessage, ExitCode=$exitCode"

if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    Write-SetupLog "---- Begin stdout ----"
    $stdout -split "`r?`n" | Where-Object { $_ -ne "" } | ForEach-Object { Write-SetupLog $_ }
    Write-SetupLog "---- End stdout ----"
}

if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    Write-SetupLog "---- Begin stderr ----"
    $stderr -split "`r?`n" | Where-Object { $_ -ne "" } | ForEach-Object { Write-SetupLog $_ }
    Write-SetupLog "---- End stderr ----"
}

exit $exitCode
