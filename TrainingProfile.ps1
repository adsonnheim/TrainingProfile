Function Format-Name() {
    Param (
        $Name
    )

    If (($Name -split ' ').Count -ne 2) {
        Return $False
    }

    Return (($Name -split ' ', 2)[0].SubString(0, 1).ToUpper() + ($Name -split ' ', 2)[0].SubString(1, ($Name -split ' ', 2)[0].Length - 1).ToLower()) + " " + (($Name -split ' ', 2)[1].SubString(0, 1).ToUpper() + ($Name -split ' ', 2)[1].SubString(1, ($Name -split ' ', 2)[1].Length - 1).ToLower())
}

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

$FirstUser = "0"
$SecondUser = "1"
$Fails = 0

While ($FirstUser -ne $SecondUser) {
    If ($Fails -ne 0) {
        Write-Host "ERROR: Names do not match" -ForegroundColor Red
    }

    $FirstInput = ((Read-Host "Enter the first and last name of the user you wish to create a training profile for") -replace '\s+', ' ').Trim()
    $FirstUser = Format-Name($FirstInput)

    $SecondInput = ((Read-Host "Re-type the first and last name of the user to verify") -replace '\s+', ' ').Trim()
    $SecondUser = Format-Name($SecondInput)

    $Fails++
}

$FirstUser