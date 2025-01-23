############################################
#*/#
#*/#
#*/#
#*/#
#*/#
#*/#
#*/# -----Pre Defined Variables----- #*/#
$desktop = [Environment]::GetFolderPath("Desktop")
$EmailSender = ""
$smtpServer = ""
$description = "This account has been disabled"
$whatif = $true
$GoodUsers = @()
$allResults = @()
$output = "$($desktop)\StriklistResults_$((Get-Date).ToString('yyyyMMdd')).csv"


function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "TRACE")]
        [string]$LogLevel = "INFO",

        [Parameter()]
        [string]$LogFilePath = "$desktop\Strike_logfile.log"
    )

    $logDirectory = Split-Path -Path $LogFilePath
    if (!(Test-Path -Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$LogLevel] $Message"

    try {
        Add-Content -Path $LogFilePath -Value $logEntry -Force
    }
    catch {
        Write-Error "Failed to write to log file: $_"
    }
}
$MasterList = Import-Csv "$($desktop)\masterlist.csv"
# Validate masterlist file
$PathTest = Test-Path "$desktop\masterlist.csv"
if ($PathTest -eq $false) {
    Write-Host "Masterlist not found, please create a masterlist.csv file on your desktop"
    break
}
else {
    foreach ($userAccount in $MasterList) {
        try {
            # Initial Disable/Set Description/Replace Info
            $getUser = Get-ADUser $userAccount.SamAccountName -ErrorAction Stop
            Disable-ADAccount -Identity $userAccount.SamAccountName -ErrorAction Stop -WhatIf:$whatif
            Set-ADUser -Identity $userAccount.SamAccountName -Description $description -ErrorAction Stop -WhatIf:$whatif
            Set-ADUser -Identity $getUser -Replace @{info = "PLEASEREPLACE" } -ErrorAction Stop -WhatIf:$whatif
            $GoodUsers += $getUser
        }
        catch {
            Write-Log -Message "Failed to process user account $($userAccount.SamAccountName)" -LogLevel "ERROR"
        }
    }

    # Process each user in GoodUsers
    foreach ($user in $GoodUsers) {
        try {
            $validate = Get-ADUser $user.SamAccountName -Properties Description, Info, Enabled -ErrorAction Stop
            $Results = [PSCustomObject]@{
                SamAccountName = $validate.SamAccountName
                Description    = $validate.Description
                Info           = $validate.Info
                Enabled        = $validate.Enabled
            }
            $AllResults += $Results
        }
        catch {
            Write-Log -Message "Failed to validate user account $($user.SamAccountName)" -LogLevel "ERROR"
        }
    }
}

foreach ($Finaluser in $GoodUsers) {
    $Query = Get-ADUser -Identity $Finaluser -Properties Manager, personalTitle, GivenName, Surname
    if ($null -eq $Query.Manager ) {
        Write-Log -Message "$($finaluser.samaccountname) does not have a manager" -LogLevel "WARN"
        continue
    }
    else {
        $Manager = (Get-ADUser -Identity $Query.Manager -Properties Mail | select Mail).Mail
        $UserTextName = "$($Query.personalTitle) $($query.GivenName) $($query.Surname)".ToUpper()
        $subject = "URGENT! NOTIFICATION OF ACCOUNT LOCKOUT: $($UserTextName)".ToUpper()
        $body = @"
"@.ToUpper()
        if ($whatif -eq $false) {
            Send-MailMessage -From $EmailSender -To $Manager -Subject $subject -Body $body -SmtpServer $smtpServer
        }
        else {
            Write-Host "Email would have been sent to $Manager"
        }
    }
}
$Results | Export-Csv -Path $output -NoTypeInformation -Force
