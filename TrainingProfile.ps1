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

(Get-PnPContext).ExecuteQuery()

$CurrentUser = ((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property CurrentUser) | Select-Object -ExpandProperty LoginName).Split('|')[-1]

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

    $Title = ($FirstUser + ' Training Profile')
    $Alias = ($FirstUser -replace ' ', '') + "TrainingProfile"
    $SiteURL = ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Alias)
    $HubURL = ("https://" + $Env["SHAREPOINT_URL"] + "/sites/" + $Env["HUB_SITE"])
    $Owners = $Env["OWNERS"] -split ','
    $Members = @(($FirstUser -split ' ')[0].ToLower() + "." + ($FirstUser -split ' ')[1].ToLower() + "@" + (($Env["OWNERS"] -split ',')[0] -split '@')[1])
    $ObjectID = $Env["OBJECT_ID"]
    $LoginName = ($Alias + "@" + $Env["ALIAS"]).ToLower()
    $Group = Get-PnPMicrosoft365Group | Where-Object { $_.MailNickname -eq $Alias }
    
    Try {
        Get-PnPTenantSite -Identity $SiteURL -ErrorAction Stop > $Null
        
        Write-Host "ERROR: Site with name" $SiteURL "already exists" -ForegroundColor Red
        $ValidName = $False
        $FirstUser, $SecondUser = "0", "1"
        $Fails = 0
    } Catch {
        Try {
            New-PnPSite -Type TeamSite -Title $Title -Alias $Alias -Description $Title -Members $Members

            $Group = Get-PnPMicrosoft365Group | Where-Object { $_.MailNickname -eq $Alias }
            ForEach ($Owner in $Owners) {
                Add-PnPMicrosoft365GroupOwner -Identity $Group.Id -Users $Owner
            }

            $LoginName = "c:0o.c|federateddirectoryclaimprovider|$($Group.Id)"

            Connect-PnPOnline $SiteURL -Interactive -ClientId $Env["CLIENT_ID"] -TenantAdminUrl ("https://" + $Env["SHAREPOINT_ADMIN_URL"])

            Set-PnPMicrosoft365Group -Identity $Group.Id -HideFromOutlookClients $True

            Try {
                Remove-PnPGroupMember -LoginName $LoginName -Group 5 -ErrorAction Stop
            } Catch {
                Write-Host "Removing site member failed!" -ForegroundColor Red
            }
            
            Add-PnPGroupMember -LoginName "c:0t.c|tenant|$ObjectId" -Identity "Site Members"
            Connect-PnPOnline $Env["SHAREPOINT_URL"] -Interactive -ClientId $Env["CLIENT_ID"]

            Remove-PnPMicrosoft365GroupOwner -Identity $Group.Id -Users $CurrentUser

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

        Connect-PnPOnline $HubURL -Interactive -ClientId $Env["CLIENT_ID"]
        Add-PnPListItem -List "Training Profiles" -Values @{
            "Title" = $Title
            "field_1" = $SiteURL
            "ClassroomOneDrive" = $Env["ONEDRIVE"]
        } > $Null

        $ValidName = $True
    }
}

Disconnect-PnPOnline -ClearPersistedLogin