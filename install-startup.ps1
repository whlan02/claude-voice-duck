<#
.SYNOPSIS
  Runs claude-voice-duck.ps1 automatically (hidden) every time you log in to Windows.
  Run with -Uninstall to remove it. Any other arguments (-DuckPercent, -MicKey) are passed through to the script.
#>
param(
    [switch]$Uninstall,
    [ValidateRange(0, 100)][int]$DuckPercent = 20,
    [string]$MicKey = 'AnthropicPBC.Claude_fnn82j28hfe8t'
)

$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'claude-voice-duck.lnk'

if ($Uninstall) {
    Remove-Item $lnk -ErrorAction SilentlyContinue
    Write-Host 'Removed from startup.'
    return
}

$script = Join-Path $PSScriptRoot 'claude-voice-duck.ps1'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = 'powershell.exe'
$s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -DuckPercent $DuckPercent -MicKey $MicKey"
$s.WorkingDirectory = $PSScriptRoot
$s.Save()
Write-Host "Installed. It will start at next login. Start it now with:"
Write-Host "  powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
