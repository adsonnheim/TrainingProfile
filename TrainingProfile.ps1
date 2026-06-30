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

Connect-PnPOnline $Env["SHAREPOINT_URL"] -Interactive -ClientId $Env["CLIENT_ID"]

$FirstUser, $SecondUser, $Fails, $ValidName = "0", "1", 0, $False

Read-Host "Press Ctrl + C to stop script..."

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

    $Title = ($FirstUser + ' Training Profile')
    $Alias = ($FirstUser -replace ' ', '') + "TrainingProfile"
    $SiteURL = ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Alias)
    $HubURL = ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Env["HUB_SITE"])
    $Owners = $Env["OWNERS"] -split ','
    $Members = @(($FirstUser -split ' ')[0].ToLower() + "." + ($FirstUser -split ' ')[1].ToLower() + "@" + (($Env["OWNERS"] -split ',')[0] -split '@')[1])
    
    Try {
        # Variable to prevent console output
        $SiteExists = Get-PnPTenantSite -Identity $SiteURL -ErrorAction Stop
        
        Write-Host "ERROR: Site with name" $SiteURL "already exists" -ForegroundColor Red
        $ValidName = $False
        $FirstUser, $SecondUser = "0", "1"
        $Fails = 0
    } Catch {
        Write-Host "Creating site" $SiteURL
        Try {
            New-PnPSite -Type TeamSite -Title $Title -Alias $Alias -Description $Title -Members $Members

            $Group = Get-PnPMicrosoft365Group | Where-Object { $_.MailNickname -eq $Alias }
            ForEach ($Owner in $Owners) {
                Add-PnPMicrosoft365GroupOwner -Identity $Group.Id -Users $Owner
            }

            #Remove-PnPMicrosoft365GroupOwner -Identity $Group.Id -Users "toberemoved"

        } Catch {
            Write-Host "Site Created"
        }
        
        $HubAssociated = $False
        While (-not $HubAssociated) {
            Try {
                Add-PnPHubSiteAssociation -Site $SiteURL -HubSite $HubURL -ErrorAction Stop
                $HubAssociated = $True
            } Catch {
                Write-Host "Retrying..."
                Start-Sleep -Seconds 5
            }
        }

        $ValidName = $True
    }
}

Disconnect-PnPOnline -ClearPersistedLogin