' Starts claude-voice-duck.ps1 with no window at all (window style 0).
' Extra arguments (e.g. -DuckPercent 20) are passed through to the script.
' Safe to run any number of times: the script exits if a copy is already running.
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\claude-voice-duck.ps1"""
For Each a In WScript.Arguments
    cmd = cmd & " " & a
Next
CreateObject("WScript.Shell").Run cmd, 0, False
