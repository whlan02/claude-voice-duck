# claude-voice-duck

Automatically lowers your Windows system volume while **Claude Desktop** is recording voice input, and restores it when you stop. Made for people who work with music playing and don't want it picked up by dictation.

- Starts ducking the moment you press record, not when you start talking, so pauses while you think don't let the music back in.
- Runs invisibly in the background (no console window), starts at login, and restarts itself if you close it by accident.
- Plain PowerShell. No dependencies, no admin rights.

## Why this exists

Apps like WeChat get this behavior for free: Windows has a "reduce other sounds during communications" setting (`mmsys.cpl` → Communications tab). But it only triggers for apps that flag their microphone stream as "communications" (WeChat, Teams, Zoom and similar). Claude Desktop doesn't, so that setting does nothing for it. This tool fills the gap.

## How it works

Windows records which apps are using the microphone under  
`HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone`.  
While an app holds the microphone open, its `LastUsedTimeStop` value is `0`. The script polls that value every 200 ms:

- microphone opened (you press record) → system volume is set to `DuckPercent`% of its current level
- microphone closed (you stop recording) → volume is restored to what it was

The script only reads that registry key. It does not change any system settings or registry values.

## Requirements

- Windows 10 or 11 with the built-in Windows PowerShell 5.1
- Claude Desktop for Windows, Microsoft Store / MSIX version (package `AnthropicPBC.Claude_fnn82j28hfe8t`). For another build or app, see [Using it with other apps](#using-it-with-other-apps).

## Quick start

Get the code somewhere **permanent** (the scheduled task will point at this folder):

```powershell
git clone https://github.com/whlan02/claude-voice-duck.git D:\tools\claude-voice-duck
cd D:\tools\claude-voice-duck
```

Install:

```powershell
powershell -ExecutionPolicy Bypass -File .\manage.ps1 install
```

That's it. Open Claude Desktop, play some music, press the voice-input button: the volume should drop immediately and come back when you stop.

> If you downloaded a ZIP instead of cloning, run `Get-ChildItem -Recurse | Unblock-File` in the folder first, otherwise Windows may refuse to run the scripts.

`install` does four things:

1. Starts the script now, with **no window**. It is launched through `start-hidden.vbs` (window style 0), so no console ever appears.
2. Creates a scheduled task `claude-voice-duck` that runs at every login **and every 5 minutes**. If the script is already running it does nothing; if it isn't (you closed it, it crashed), it starts it again.
3. Puts a **Start Claude Voice Duck** shortcut on your desktop for starting it by hand.
4. Removes any older start-up shortcut from earlier versions.

Running `install` again is always safe, and so is starting the script any number of times: only one copy can run at a time.

## Everyday use

Run these from the repo folder. (`-ExecutionPolicy Bypass` is only needed if your PowerShell blocks local scripts; it is harmless otherwise.)

| Command | What it does |
| --- | --- |
| `powershell -ExecutionPolicy Bypass -File .\manage.ps1 status` | Shows whether it is running and whether auto-start is on |
| `... manage.ps1 stop` | Stops it (volume is restored first) **and pauses auto-start** |
| `... manage.ps1 start` | Starts it and turns auto-start back on |
| `... manage.ps1 install -DuckPercent 10` | Reinstalls with a different ducked volume (default 20) |
| `... manage.ps1 uninstall` | Stops it and removes the scheduled task and the desktop shortcut |

Don't want to type anything? Double-click the **Start Claude Voice Duck** shortcut on your desktop. It is safe to click when it is already running.

### Stopping it

Use `manage.ps1 stop`. It restores the volume and pauses the 5-minute check, so it stays off until you run `start`.

If you instead end the process in Task Manager, the 5-minute check will start it again within 5 minutes. That is intentional: it is what brings it back after an accidental close.

To find the process in Task Manager anyway:

1. Press `Ctrl + Shift + Esc`.
2. **Windows 11:** type `powershell` into the search box at the top. **Windows 10:** open the Details tab.
3. The script shows up as **Windows PowerShell** (`powershell.exe`). If you have other PowerShell windows open, several entries may match: go to the **Details** tab, right-click a column header → *Select columns* → tick **Command line**, and pick the one containing `claude-voice-duck.ps1`.

If you end it while the volume is ducked, the volume stays low until you raise it yourself (see [Limitations](#limitations)).

## Options

| Parameter | Default | Meaning |
| --- | --- | --- |
| `-DuckPercent` | `20` | Volume while recording, as a percentage of the volume before recording started (0–100) |
| `-MicKey` | `AnthropicPBC.Claude_fnn82j28hfe8t` | Which app's microphone usage to watch (see below) |

Pass them to `manage.ps1 install`; they are saved into the scheduled task and the desktop shortcut. To run the script by hand in a console instead (it stays in the foreground, Ctrl+C to stop):

```powershell
.\claude-voice-duck.ps1 -DuckPercent 20
```

## Using it with other apps

`-MicKey` is the app's key name under  
`HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone`  
(Store/packaged apps), or under `...\microphone\NonPackaged` (classic `.exe` apps, where path separators are written as `#`, e.g. `C:#Program Files#App#app.exe`). The script checks both locations.

To find the key: open the app, start recording in it, then list which key has `LastUsedTimeStop` = `0`:

```powershell
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' -Recurse |
  ForEach-Object { $p = Get-ItemProperty $_.PSPath; if ($p.LastUsedTimeStop -eq 0) { $_.PSChildName } }
```

Then install with it: `manage.ps1 install -MicKey "<that name>"`.

## Troubleshooting

- **Nothing happens when I record.** Run `manage.ps1 status`. If it says *Running: NO*, run `manage.ps1 start`. If it is running, make sure you are recording in the Store version of Claude Desktop; if your build has a different package name, see the `-MicKey` section above.
- **Volume is stuck low.** The script was force-killed while ducking. Raise the volume manually.
- **It stopped working after I moved the folder.** The scheduled task and the desktop shortcut point at the folder you installed from. Run `manage.ps1 install` again from the new location.
- **It keeps coming back after I close it.** That is the 5-minute check. Use `manage.ps1 stop` to pause it, or `uninstall` to remove it.
- **"Running scripts is disabled on this system".** Use the `powershell -ExecutionPolicy Bypass -File ...` form shown above.

## Limitations

- It changes the **master** volume, so every sound drops, including Claude's own. It cannot duck only the music player.
- If you change the volume yourself while it is ducked, it is reset to the pre-recording level when you stop recording.
- If the script is force-killed (not stopped with `manage.ps1 stop`) while ducked, the volume stays low until you raise it.
- There is no tray icon. Use `manage.ps1 status` to check on it.
- After an accidental close, it can take up to 5 minutes to come back.
- Windows only, and only for apps that appear in the Windows microphone usage list.

## Files

| File | Purpose |
| --- | --- |
| `claude-voice-duck.ps1` | The script: watches the microphone state and ducks/restores the volume. Exits immediately if another copy is running. |
| `start-hidden.vbs` | Starts the script with no window. Used by the scheduled task and the desktop shortcut. |
| `manage.ps1` | `install`, `status`, `start`, `stop`, `uninstall`. |
| `LICENSE` | MIT |

## License

MIT
