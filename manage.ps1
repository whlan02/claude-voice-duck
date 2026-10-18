<#
.SYNOPSIS
  Install, check, start and stop claude-voice-duck.

.EXAMPLE
  .\manage.ps1 install     # start now, start at every login, re-check every 5 minutes, add a desktop shortcut
  .\manage.ps1 status      # is it running?
  .\manage.ps1 start       # start it now (and re-enable auto-start)
  .\manage.ps1 stop        # stop it and pause auto-start
  .\manage.ps1 uninstall   # stop it and remove everything it set up
  .\manage.ps1 install -DuckPercent 10
#>
param(
    [ValidateSet('install', 'uninstall', 'status', 'start', 'stop')][string]$Action = 'status',
    [ValidateRange(0, 100)][int]$DuckPercent = 20,
    [string]$MicKey = 'AnthropicPBC.Claude_fnn82j28hfe8t'
)

$task     = 'claude-voice-duck'
$vbs      = Join-Path $PSScriptRoot 'start-hidden.vbs'
$mutexName = 'Local\claude-voice-duck'
$stopName  = 'Local\claude-voice-duck-stop'
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Start Claude Voice Duck.lnk'
$oldStartupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'claude-voice-duck.lnk'

function Test-Running {
    $m = $null
    if ([System.Threading.Mutex]::TryOpenExisting($mutexName, [ref]$m)) { $m.Dispose(); return $true }
    return $false
}

function Get-DuckProcesses {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -match 'claude-voice-duck\.ps1|claude-duck\.ps1' -and $_.ProcessId -ne $PID }
}

function Stop-Duck {
    # Ask politely first so the script can restore the volume, then force-kill leftovers.
    $e = $null
    if ([System.Threading.EventWaitHandle]::TryOpenExisting($stopName, [ref]$e)) { [void]$e.Set(); $e.Dispose() }
    for ($i = 0; $i -lt 20 -and (Test-Running); $i++) { Start-Sleep -Milliseconds 200 }
    Get-DuckProcesses | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Start-Duck {
    Start-Process wscript.exe -ArgumentList "//B `"$vbs`" -DuckPercent $DuckPercent -MicKey $MicKey"
    for ($i = 0; $i -lt 25 -and -not (Test-Running); $i++) { Start-Sleep -Milliseconds 200 }
}

switch ($Action) {
    'install' {
        Stop-Duck   # also replaces old copies that predate the single-instance check

        $arg = "//B `"$vbs`" -DuckPercent $DuckPercent -MicKey $MicKey"
        $act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument $arg -WorkingDirectory $PSScriptRoot
        $atLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $every5  = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
        $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                   -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
        $pr  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $task -Action $act -Trigger @($atLogon, $every5) -Settings $set -Principal $pr -Force | Out-Null

        $sh = New-Object -ComObject WScript.Shell
        $s = $sh.CreateShortcut($desktopLnk)
        $s.TargetPath = 'wscript.exe'
        $s.Arguments = $arg
        $s.WorkingDirectory = $PSScriptRoot
        $s.IconLocation = 'mmsys.cpl,0'
        $s.Save()

        Remove-Item $oldStartupLnk -ErrorAction SilentlyContinue   # replaced by the scheduled task
        Start-Duck
        Write-Host ("Installed. Running now: " + (Test-Running))
        Write-Host 'It starts at every login and is re-checked every 5 minutes. Check with: .\manage.ps1 status'
        Write-Host "The task points at this folder ($PSScriptRoot); if you move it, run '.\manage.ps1 install' again."
    }
    'uninstall' {
        Stop-Duck
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item $desktopLnk, $oldStartupLnk -ErrorAction SilentlyContinue
        Write-Host 'Stopped and removed.'
    }
    'status' {
        Write-Host ("Running:      " + $(if (Test-Running) { 'yes' } else { 'NO' }))
        $t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        Write-Host ("Auto-start:   " + $(if (-not $t) { 'not installed (run: .\manage.ps1 install)' }
                                          elseif ($t.State -eq 'Disabled') { 'paused (run: .\manage.ps1 start)' }
                                          else { 'on (login + every 5 min)' }))
    }
    'start' {
        Enable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        Start-Duck
        Write-Host ("Running: " + (Test-Running))
    }
    'stop' {
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        Stop-Duck
        Write-Host ("Stopped. Auto-start paused until you run '.\manage.ps1 start'. Running: " + (Test-Running))
    }
}
