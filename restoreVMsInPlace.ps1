# This script restores VMs in-place as specified in file with one VM per line
# If using domain credentials then use format user@domain.example
# Create folder C:\cvscripts and run script from this folder
# Create an input file in C:\cvscripts called vmlist.txt with one VM per line.

# Setup logging
$Logfile = "C:\cvScripts\restoreVmsInPlace.log"

# Specify your CommServe URL here
$cs = "http://commserve1.cv.lab"

function WriteLog
{

    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage

}

# Let's login and get a token!
$credential = Get-Credential -Message "Enter Commvault Admin Credentials"
$username = $credential.UserName
$password = $credential.GetNetworkCredential().password

# The password needs to be in base64 format
$password = [System.Text.Encoding]::UTF8.GetBytes($password)
$password = [System.Convert]::ToBase64String($password)

# Login
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Content-Type", "application/json")
$body = "{`n  `"password`": `"$password`",`n  `"username`": `"$username`",`n  `"timeout`" : 30`n}"
$response = Invoke-RestMethod "$cs/webconsole/api/Login" -Method 'POST' -Headers $headers -Body $body

# We need to get the token
$token = $response | Select-Object -ExpandProperty token
# The first five characters need to be removed to get just the token
$token = $token.substring(5)

# Now that we have a token we can do things
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authtoken", "$token")
$headers.Add("Content-Type", "application/json")

# Open file with one VM per line
$vms = Get-Content C:\cvScripts\vmlist.txt

# Get total list of VM's in CommCell
$ccVms = Invoke-RestMethod "$cs/webconsole/api/VM" -Method 'GET' -Headers $headers

# Loop through each VM and get GUID then restore in-place with overwrite
foreach ($vm in $vms) {

    # Get VM GUID for VM name 
    $vmGuid = $ccVms.vmStatusInfoList | Where-Object name -eq $vm | Select-Object -ExpandProperty strGUID

    if ($null -ne $vmGuid) {

        # Options for restore provided in XML
        $body = "<Api_VMRestoreReq powerOnVmAfterRestore =`"true`" passUnconditionalOverride=`"true`" inPlaceRestore=`"true`">`n</Api_VMRestoreReq>"
        # Initiate restore job for VM
        $response = Invoke-RestMethod "$cs/webconsole/api/v2/vsa/vm/$vmGuid/recover" -Method 'POST' -Headers $headers -Body $body -ContentType 'application/xml'
        #$response | ConvertTo-Json -depth 10
        $jobid = $response | Select-Object -ExpandProperty jobIds
        Write-Host "VM: $vm with $vmGuid in-place and overwrite restore started with JobID: $jobid"
        WriteLog "VM: $vm with $vmGuid in-place and overwrite restore started with JobID: $jobid"
 
    } else {
        Write-Host "VM: $vm not found in CommCell"
        WriteLog "VM: $vm not found in CommCell"
    }

}