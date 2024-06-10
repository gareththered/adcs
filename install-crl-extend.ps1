$eventSrc = "CRL Distribution"

$schedTask = "CRL Extender"

##################################################################################################

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
    <Date>2016-09-21T15:38:58.9851263</Date>
    <Author>EXAMPLE\administrator</Author>
    <Description>Runs Certutil.exe to generate a CRL with extended expiry date so that it can be used by Overseas.</Description>
    </RegistrationInfo>
    <Triggers>
    <EventTrigger>
        <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
        <Enabled>true</Enabled>
        <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Security"&gt;&lt;Select Path="Security"&gt;*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4872]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    </Triggers>
    <Principals>
    <Principal id="Author">
        <UserId>S-1-5-18</UserId>
        <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
    </Principals>
    <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
        <StopOnIdleEnd>true</StopOnIdleEnd>
        <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>false</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
    </Settings>
    <Actions Context="Author">
    <Exec>
        <Command>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
        <Arguments>C:\PKIScripts\CRLextend.ps1</Arguments>
    </Exec>
    </Actions>
</Task>
"@

# Register the Eventlog source:
if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$eventSrc"))
{
    New-EventLog -LogName Application -Source $eventSrc -ErrorAction SilentlyContinue
    Write-EventLog  -LogName Application -Source $eventSrc -Category 0 -EntryType Information `
                    -EventId 1000 -Message "Registered Event Source `"$eventSrc`"`n"
}

# Register a Scheduled Task

if (Get-ScheduledTask | Where-Object {$_.TaskName -eq $schedTask })
{
    Unregister-ScheduledTask -TaskName $schedTask -Confirm:$false
}

$xmlPath = [System.IO.Path]::GetTempFileName()

$xml | Out-File $xmlPath

schtasks.exe /Create  /TN "PKI\$schedTask" /XML $xmlPath

Remove-Item $xmlPath
