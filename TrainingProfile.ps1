$EnvFilePath = "./.env.local"

If (-not (Test-Path $EnvFilePath -PathType Leaf)) {
    Write-Error "Error: .env.local file not found at $($EnvFilePath)"
    Exit 1
}

$Env = @{}
$EnvLines = Get-Content $EnvFilePath

ForEach ($Line in $EnvLines) {
    $TrimmedLine = $Line.Trim()

    If ([string]::IsNullOrEmpty($TrimmedLine) -or $TrimmedLine.StartsWith('#')) {
        Continue
    }

    $Name, $Value = $TrimmedLine -split '=', 2
    $Env.Add($Name, $Value)
}

If (-not (Get-Module -ListAvailable -Name PnP.Powershell)) {
    Write-Host "PnP.Powershell module not found, installing dependencies..."
    Install-Module PnP.Powershell
}

Connect-PnPOnline $Env["SHAREPOINT_URL"] -Interactive -ClientId $Env["CLIENT_ID"]