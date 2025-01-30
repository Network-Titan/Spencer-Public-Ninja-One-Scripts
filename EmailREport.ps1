$desktop = [System.Environment]::GetFolderPath('Desktop')
$path = "$desktop\AdminGroups.csv"

$csv = Import-Csv $path

$data = $csv | Foreach-Object -ThrottleLimit 10 -Parallel {

    try {
        $groupname = $_.name.split('x\')[1]
    $ADGroup = Get-ADGroupMember $groupname | where { $_.objectClass -eq 'user' } -and $_.SamAccountName -NotMatch ".ADD|.ADW|.ADF|.ADC|.ADM|SVC.|.ADX" -ErrorAction Stop
    if ($ADGroup.count -ge 1) {
        $PsCustomOut = [PSCustomObject]@{
            Name = $groupname
            Member_Count = $ADGroup.Count
            Computer_Count = $_.count
        }
        $PsCustomOut | Out-File "$desktop\OffendingGroups.csv" -Append
    }
    }
    catch {
        
    }
    


}
