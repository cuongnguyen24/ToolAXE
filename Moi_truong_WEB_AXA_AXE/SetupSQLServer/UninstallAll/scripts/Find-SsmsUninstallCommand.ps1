param()

$ErrorActionPreference = "SilentlyContinue"

$roots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$entries = Get-ItemProperty -Path $roots -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*SQL Server Management Studio*" } |
    Sort-Object DisplayVersion -Descending

if (-not $entries) {
    exit 1
}

foreach ($entry in $entries) {
    $command = if (-not [string]::IsNullOrWhiteSpace($entry.QuietUninstallString)) {
        $entry.QuietUninstallString
    } else {
        $entry.UninstallString
    }

    if ([string]::IsNullOrWhiteSpace($command)) {
        continue
    }

    $trimmed = $command.Trim()
    $filePath = ""
    $argumentString = ""

    if ($trimmed.StartsWith('"')) {
        $endQuote = $trimmed.IndexOf('"', 1)
        if ($endQuote -gt 0) {
            $filePath = $trimmed.Substring(1, $endQuote - 1)
            $argumentString = $trimmed.Substring($endQuote + 1).Trim()
        }
    } else {
        $firstSpace = $trimmed.IndexOf(' ')
        if ($firstSpace -gt 0) {
            $filePath = $trimmed.Substring(0, $firstSpace)
            $argumentString = $trimmed.Substring($firstSpace + 1).Trim()
        } else {
            $filePath = $trimmed
        }
    }

    if ([string]::IsNullOrWhiteSpace($filePath)) {
        continue
    }

    $normalizedPath = $filePath.Trim().ToLowerInvariant()
    $normalizedArgs = $argumentString.Trim().ToLowerInvariant()
    if (
        $normalizedPath -eq "c:\program files (x86)\microsoft visual studio\installer\setup.exe" -and
        $normalizedArgs -like "uninstall --installpath*"
    ) {
        if ($normalizedArgs -notlike "*--quiet*") {
            $argumentString = "$argumentString --quiet"
        }
        if ($normalizedArgs -notlike "*--norestart*") {
            $argumentString = "$argumentString --norestart"
        }
        if ($normalizedArgs -notlike "*--force*") {
            $argumentString = "$argumentString --force"
        }
    }

    Write-Output ("{0}`t{1}`t{2}`t{3}" -f $entry.DisplayName, $entry.DisplayVersion, $filePath, $argumentString)
}

exit 0
