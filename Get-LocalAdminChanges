<#
.SYNOPSIS
    This script checks for changes to the local Administrators group within a specified time frame 
    (default is 30 minutes). It verifies if auditing for Security Group Management is enabled 
    and enforces it if necessary, and then retrieves events indicating user additions or removals 
    from the group.

.DESCRIPTION
    The function `Get-LocalAdminGroupChanges` is used to check the local Windows Security event log 
    for changes to the Administrators group. It retrieves events such as the addition or removal 
    of members within a defined time window (default 30 minutes). 
    It ensures that auditing for Security Group Management is enabled by checking and, if needed, 
    enabling Success and Failure audits.

.PARAMETER MinutesAgo
    Specifies how far back in time (in minutes) the script should look for changes to the local 
    Administrators group. The default is 30 minutes.

.PARAMETER SuccessOutputlogs
    A boolean parameter that controls whether to display success messages for audit settings. 
    By default, it's set to `$true`. Set to `$false` to display all output messages.

.EXAMPLE
    Get-LocalAdminGroupChanges -MinutesAgo 60 -SuccessOutputlogs $false
    Retrieves changes to the local Administrators group within the last 60 minutes. and displays the sucess output logs.
    ------------- LOG OUTPUT START -------------
    Success auditing for Security Group Management is already enabled.
    Failure auditing for Security Group Management is already enabled.
    Audit policy for Security Group Management is now set to Success and Failure.

TimeCreated          Action  TargetAccount    ActorAccount
-----------          ------  -------------    ------------
9/12/2024 2:21:08 PM Removed DESKTOP\Guest    TestUser
9/12/2024 1:54:25 PM Added   DESKTOP\Guest    TestUser
------------- LOG OUTPUT END -------------

.EXAMPLE
    Get-LocalAdminGroupChanges -SuccessOutputlogs $false

TimeCreated          Action  TargetAccount    ActorAccount
-----------          ------  -------------    ------------
9/12/2024 2:21:08 PM Removed DESKTOP\Guest    TestUser
9/12/2024 1:54:25 PM Added   DESKTOP\Guest    TestUser

.NOTES
    Author: https://github.com/Sp-e-n-c-er
    Date: 12th September 2024
    This script is designed to work on systems where Security Group Management auditing is enabled 
    and configured to log group membership changes in the Security event log.

#>

function Get-LocalAdminGroupChanges {
    param (
        [int]$MinutesAgo = 30, # How far back in time to check (default is 30 minutes)
        [bool]$SuccessOutputlogs = $true # Displays write-output messages for success only, false will always display
    )

    # Helper function to check and enable audit policy
    function Ensure-AuditPolicyEnabled {
        # Get the current audit policy for Security Group Management
        $auditPolicy = auditpol /get /subcategory:"Security Group Management"

        # Check if both Success and Failure are enabled using exact matching
        $successEnabled = $auditPolicy -match 'Success'
        $failureEnabled = $auditPolicy -match 'Failure'

        # Enable Success if not already enabled
        if (-not $successEnabled) {
            Write-Output "Success auditing for Security Group Management is not enabled. Enabling it..."
            auditpol /set /subcategory:"Security Group Management" /success:enable
        } 
        elseif($SuccessOutputlogs) {
            Write-Output "Success auditing for Security Group Management is already enabled."
        }

        # Enable Failure if not already enabled
        if (-not $failureEnabled) {
            Write-Output "Failure auditing for Security Group Management is not enabled. Enabling it..."
            auditpol /set /subcategory:"Security Group Management" /failure:enable
        } 
        elseif ($SuccessOutputlogs) {
            Write-Output "Failure auditing for Security Group Management is already enabled."
        }

        # Re-check to confirm it's now enabled
        $auditPolicy = auditpol /get /subcategory:"Security Group Management"
        $successEnabled = $auditPolicy -match 'Success'
        $failureEnabled = $auditPolicy -match 'Failure'

        if ($successEnabled -and $failureEnabled) {
            if ($SuccessOutputlogs) {
                Write-Output "Audit policy for Security Group Management is now set to Success and Failure."
            }
        }
        else {
            Write-Output "Failed to enable the necessary audit policies." -ForegroundColor Red
        }
    }

    # Check and ensure the right audit policy is enabled
    Ensure-AuditPolicyEnabled

    # Define the SID for the local Administrators group
    $adminGroupSID = "S-1-5-32-544"

    # Define the event IDs for group changes (Added/Removed)
    $eventIDs = 4728, 4729, 4732, 4733, 4756, 4757

    # Calculate the start time for the event query
    $startDate = (Get-Date).AddMinutes(-$MinutesAgo)

    # Query the Security Event Log for relevant events
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security';
        Id        = $eventIDs;
        StartTime = $startDate
    } -ErrorAction SilentlyContinue

    # Initialize an array to store the results
    $results = @()

    # Iterate through the events and extract relevant information
    foreach ($event in $events) {
        # Parse the XML for detailed information
        $eventXml = [xml]$event.ToXml()

        # Extract event details
        $timeCreated = $event.TimeCreated
        $eventId = $event.Id
        $actorAccount = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
        $groupSID = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetSid' } | Select-Object -ExpandProperty '#text'

        # Ensure the event is for the Administrators group (SID = S-1-5-32-544)
        if ($groupSID -eq $adminGroupSID) {
            # Extract the security ID of the account being added or removed
            $memberSID = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'MemberSid' } | Select-Object -ExpandProperty '#text'
            
            # Convert the SID to a readable username
            $targetAccount = try { 
                (New-Object System.Security.Principal.SecurityIdentifier($memberSID)).Translate([System.Security.Principal.NTAccount]).Value 
            }
            catch {
                $memberSID  # If unable to resolve, display the SID
            }

            # Determine action based on Event ID
            $action = if ($eventId -in 4728, 4732, 4756) { "Added" } elseif ($eventId -in 4729, 4733, 4757) { "Removed" }

            # Create a custom object to store the result
            $result = [PSCustomObject]@{
                TimeCreated   = $timeCreated
                Action        = $action
                TargetAccount = $targetAccount
                ActorAccount  = $actorAccount
            }

            # Add the result to the results array
            $results += $result
        }
    }

    # Output the results as a table
    if ($results.Count -eq 0) {
        Write-Host "No changes to the Administrators group found in the last $MinutesAgo minutes."
    }
    else {
        $results | Format-Table -AutoSize
    }
}
