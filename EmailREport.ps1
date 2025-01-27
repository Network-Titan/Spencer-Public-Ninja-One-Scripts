####################################################
#/# Customizable Variables
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$csvPath = "$($desktopPath)\strike list.csv"
$errorLogPath = "$($desktopPath)\strike_list_errors_$(Get-Date -Format yyyyMMdd).log"
$description = "FILLER MESSAGE FOR DESCRIPTION"
$SenderEmail = "here@test.com"
$SMTPServer = "smtp.test.com"
$whatif = $true
#/#
####################################################


if (!(Test-Path -Path $csvPath)) {
    Write-Host "CSV file not found at: $csvPath" -ForegroundColor Red
    exit
}
if (Test-Path $errorLogPath) {
    Remove-Item -Path $errorLogPath -Force
}
New-Item -Path $errorLogPath -ItemType File -Force | Out-Null

foreach ($user in $users) {
    $samAccountName = $($user.samaccountname)
    $aduser = $null
    $adUser = Get-ADUser $samAccountName -ErrorAction SilentlyContinue -Properties mail, personalTitle, surname, givenName
    if ($nul -eq $adUser) {
        $errorMessage = "User '$samAccountName' not found in Active Directory."
        Add-Content -Path $errorLogPath -Value $errorMessage
        Write-Host $errorMessage -ForegroundColor Yellow
        continue
    }

    try {
        Disable-ADAccount -Identity $adUser -ErrorAction Stop -WhatIf:$whatif
    }
    catch {
        $errorMessage = "Failed to disable user '$samAccountName'. Error: $_"
        Add-Content -Path $errorLogPath -Value $errorMessage
        Write-Host $errorMessage -ForegroundColor Red
        continue
    }

    try {
        Set-ADUser -Identity $adUser -Description $description -Replace @{info = $description } -ErrorAction Stop -whatif:$whatif
    }
    catch {
        $errorMessage = "Failed to update attributes for user '$samAccountName'. Error: $_"
        Add-Content -Path $errorLogPath -Value $errorMessage
        Write-Host $errorMessage -ForegroundColor Red
        continue
    }

    $updatedUser = Get-ADUser -Identity $adUser -Properties Enabled, Description, Info
    if ($updatedUser.Enabled -ne $false -or $updatedUser.Description -ne $description -or $updatedUser.Info -ne $description) {
        $errorMessage = "Verification failed for user '$samAccountName'."
        Add-Content -Path $errorLogPath -Value $errorMessage
        Write-Host $errorMessage -ForegroundColor Yellow
        continue
    }

    try {
        $managerDN = $updatedUser.Manager
        if ($managerDN) {
            $manager = Get-ADUser -Identity $managerDN -Properties mail
            if ($manager.mail) {
                if ($whatif -eq $false) {
                    $OffenderName = "$($aduser.personalTitle) $($aduser.surname) $($aduser.givenName)".ToUpper()
                    $subject = "URGENT ACCOUNT DISABLED NOTIFICATION: $OffenderName"
                    $body = @"

                    INPUT MESSAGE HERE
"@.ToUpper()
                    Send-MailMessage -From $SenderEmail -To $manager.mail -Subject $subject -Body $body -SmtpServer $SMTPServer
                }
                else {
                    Write-Host "Email would be sent to $($manager.mail) for user $samAccountName" -ForegroundColor Green
                }
            }
            else {
                $errorMessage = "Manager for user $($samAccountName) does not have an email address."
                Add-Content -Path $errorLogPath -Value $errorMessage
                Write-Host $errorMessage -ForegroundColor Yellow
            }
        }
        else {
            $errorMessage = "User '$samAccountName' does not have a manager assigned."
            Add-Content -Path $errorLogPath -Value $errorMessage
            Write-Host $errorMessage -ForegroundColor Yellow
        }
    }
    catch {
        $errorMessage = "Failed to send email for user '$samAccountName'. Error: $_"
        Add-Content -Path $errorLogPath -Value $errorMessage
        Write-Host $errorMessage -ForegroundColor Red
    }
}
