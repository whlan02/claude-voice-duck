<#
.SYNOPSIS
  Lowers the system volume while Claude Desktop is recording (voice input), restores it afterwards.

.PARAMETER DuckPercent
  Volume while recording, as a percentage of the volume before recording started. Default 20.

.PARAMETER MicKey
  Name of the app's key under Windows' microphone ConsentStore. Default is the Claude Desktop (Store/MSIX) package.
  To duck for another app, look under
  HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone
  (packaged apps) or ...\microphone\NonPackaged (classic .exe apps; use the key name as shown).
#>
param(
    [ValidateRange(0, 100)][int]$DuckPercent = 20,
    [string]$MicKey = 'AnthropicPBC.Claude_fnn82j28hfe8t'
)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float level, Guid ctx);
    int j();
    int GetMasterVolumeLevelScalar(out float level);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid id, int clsCtx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int f(); int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }
public static class Vol {
    static IAudioEndpointVolume Ep() {
        var en = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);
        var iid = typeof(IAudioEndpointVolume).GUID; object o;
        dev.Activate(ref iid, 1, IntPtr.Zero, out o);
        return (IAudioEndpointVolume)o;
    }
    public static float Get() { float v; Ep().GetMasterVolumeLevelScalar(out v); return v; }
    public static void Set(float v) { Ep().SetMasterVolumeLevelScalar(v, Guid.Empty); }
}
'@

$base = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone'
$paths = @("$base\$MicKey", "$base\NonPackaged\$MicKey")
$ducked = $false
$orig = 0.0

try {
    while ($true) {
        $recording = $false
        foreach ($path in $paths) {
            $p = Get-ItemProperty $path -ErrorAction SilentlyContinue
            # LastUsedTimeStop is 0 while the app holds the microphone open.
            if ($p -and $p.LastUsedTimeStop -eq 0) { $recording = $true; break }
        }
        if ($recording -and -not $ducked) {
            $orig = [Vol]::Get()
            [Vol]::Set([float]($orig * $DuckPercent / 100))
            $ducked = $true
        } elseif (-not $recording -and $ducked) {
            [Vol]::Set([float]$orig)
            $ducked = $false
        }
        Start-Sleep -Milliseconds 200
    }
} finally {
    if ($ducked) { [Vol]::Set([float]$orig) }
}
