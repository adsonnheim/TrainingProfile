Function Format-Name() {
    Param (
        $Name
    )

    If (($Name -split ' ').Count -ne 2) {
        Return $False
    }

    Return (($Name -split ' ', 2)[0].SubString(0, 1).ToUpper() + ($Name -split ' ', 2)[0].SubString(1, ($Name -split ' ', 2)[0].Length - 1).ToLower()) + " " + (($Name -split ' ', 2)[1].SubString(0, 1).ToUpper() + ($Name -split ' ', 2)[1].SubString(1, ($Name -split ' ', 2)[1].Length - 1).ToLower())
}

Function Read-Input() {
    Param (
        $Message
    )

    $FirstInput = ((Read-Host $Message) -replace '\s+', ' ').Trim()
    $FirstUser = Format-Name($FirstInput)
    
    Return $FirstUser
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

$FirstUser, $SecondUser, $Fails, $ValidName = "0", "1", 0, $False

While (-not $ValidName) {
    While ($FirstUser -ne $SecondUser) {
        If ($Fails -ne 0) {
            Write-Host "ERROR: Names do not match" -ForegroundColor Red
        }

        $FirstUser = Read-Input("Enter the first and last name of the user you wish to create a training profile for")

        While ($FirstUser -eq $False) {
            Write-Host "ERROR: Must input both first name and last name" -ForegroundColor Red
            $FirstUser = Read-Input("Enter the first and last name of the user you wish to create a training profile for")
        }

        $SecondUser = Read-Input("Re-type the first and last name of the user to verify")

        While ($SecondUser -eq $False) {
            Write-Host "ERROR: Must input both first name and last name" -ForegroundColor Red
            $SecondUser = Read-Input("Re-type the first and last name of the user to verify")
        }

        $Fails++
    }

    Connect-PnPOnline $Env["SHAREPOINT_URL"] -Interactive -ClientId $Env["CLIENT_ID"]

    $Title = ($FirstUser + ' Training Profile')
    $Alias = ($FirstUser -replace ' ', '') + "TrainingProfile"

    Try {
        # Only as a variable to prevent console output
        $SiteExists = Get-PnPTenantSite -Identity ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Alias) -ErrorAction Stop
        
        Write-Host "ERROR: Site with name" ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Alias) "already exists" -ForegroundColor Red
        $ValidName = $False
        $FirstUser, $SecondUser = "0", "1"
        $Fails = 0
    } Catch {
        Write-Host "Creating site" ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Alias)
        #New-PnPSite -Type TeamSite -Title $Title -Alias $Alias
        $ValidName = $True
    }
}

Disconnect-PnPOnline -ClearPersistedLogin