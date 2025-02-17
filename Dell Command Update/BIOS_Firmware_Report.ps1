<#
.SYNOPSIS
    Dell Command Update (DCU) Scan and Result Processing Script

.DESCRIPTION
    This script runs a Dell Command Update (DCU) scan for BIOS and firmware updates, captures the output, 
    and processes the exit codes using a switch statement to set NinjaOne RMM properties based on the results.

.NOTES
    Author: Spencer Heath
    GitHub: https://github.com/Sp-e-n-c-er
    Created: 2025-02-17
    Version: 1.0

.PARAMETERS
    None

.RETURNS
    - Sets NinjaOne properties:
        - dellFirmwareOrBiosUpdateAvailable: Friendly status message
        - dellCommandUpdateBiosAndFirmwareUpdates: Full DCU error output (for non-zero exit codes)

.EXIT CODES
    Exit codes from Dell Command Update (DCU) and their meanings:
    - 0: Updates available (output displayed)
    - 1: Reboot required to complete a previous operation
    - 2: Fatal error occurred
    - 3: Not a Dell system
    - 4: CLI was not launched with administrative privileges
    - 5: Reboot required to complete a previous operation
    - 6: Dell Command Update is currently running
    - 7: System model not supported
    - 8: No update filters configured
    - 500: No updates found
    - 501-503: Error running /scan
    - 1000-1002: Error running /applyUpdates
    - 1505-1506: Error running /configure
    - 2000-2007: Error running /driverInstall
    - 2500-2502: Password encryption input validation error
    - 3000-3005: Dell Client Management Service error
    - Default: Unrecognized exit code

.LICENSE
    This script is provided as-is with no warranties. 
    Use at your own risk. Licensed under the MIT License.
#>

$DCU = (Resolve-Path "$env:SystemDrive\Program Files*\Dell\CommandUpdate\dcu-cli.exe").Path
$outputFile = "$env:Temp\Output.txt"
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$DCU`" /scan -updateType=bios,firmware -silent" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputFile
$exitCode = $process.ExitCode
$scan = Get-Content -Path $outputFile -Raw
Remove-Item -Path $outputFile -Force

switch ($exitCode) {
    1 {
        Write-Output 'Reboot required to complete a previous operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Reboot Required"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    2 {
        Write-Output 'Dell Command Update returned a fatal error.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Fatal Error"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    3 {
        Write-Output 'Not a Dell system.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Not a Dell System"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    4 {
        Write-Output 'CLI was not launched with administrative privilege.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Admin Privilege Required"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    5 {
        Write-Output 'Reboot required to complete a previous operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Reboot Required"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    6 {
        Write-Output 'Dell Command Update is currently running.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Currently Running"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    7 {
        Write-Output 'This system model is not supported by the application.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "System Model Not Supported"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    8 {
        Write-Output 'No update filters have been configured.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "No Update Filters Configured"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 100 -and $_ -le 113 } {
        Write-Output 'An input validation error has occurred.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Input Validation Error"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    500 {
        Write-Output 'No updates found.'  ## Changed behavior for code 500
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "No Updates Found"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 501 -and $_ -le 503 } {
        Write-Output 'Error running /scan. Retry the operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Scan Error - Retry"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 1000 -and $_ -le 1002 } {
        Write-Output 'Error running /applyUpdates. Retry the operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "ApplyUpdates Error - Retry"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 1505 -and $_ -le 1506 } {
        Write-Output 'Error running /configure. Retry the operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Configure Error - Retry"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 2000 -and $_ -le 2007 } {
        Write-Output 'Error running /driverInstall. Retry the operation.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "DriverInstall Error - Retry"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 2500 -and $_ -le 2502 } {
        Write-Output 'Password Encryption Input Validation Error.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Password Encryption Error"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    { $_ -ge 3000 -and $_ -le 3005 } {
        Write-Output 'Dell Client Management Service error.'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "Client Management Service Error"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
    0 {
        Write-Output "====== Available Dell Command Update Software Installs ======"
        Write-Output $scan
        Write-Output "====== End of Dell Command Update Software Installs ======"
        Write-Output 'Updates available'
        $scan | Ninja-Property-Set-Piped "dellCommandUpdateBiosAndFirmwareUpdates"
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "BIOS/Firmware Updates Available"
    }
    default {
        Write-Output 'No Valid Exit Code'
        Ninja-Property-Set "dellFirmwareOrBiosUpdateAvailable" "No Valid Exit Code"
        Ninja-Property-Set "dellCommandUpdateBiosAndFirmwareUpdates" $scan
    }
}
