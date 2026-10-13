# claude-voice-duck

[English](#english) | [中文](#中文)

## English

Automatically lowers your system volume while **Claude Desktop** is recording voice input, and restores it when you stop. Handy if you work with music playing and don't want it picked up by dictation.

Apps like WeChat get this for free because Windows has a "reduce other sounds during communications" setting (`mmsys.cpl` → Communications tab), but it only triggers for apps that flag their microphone stream as "communications". Claude Desktop doesn't, so that setting has no effect. This script fills the gap.

### How it works

Windows records which apps are currently using the microphone in the registry (`CapabilityAccessManager\ConsentStore\microphone`). While an app holds the mic open, its `LastUsedTimeStop` value is `0`. The script polls that value every 200 ms:

- mic opened (you press the record button) → system volume is set to `DuckPercent`% of its current level
- mic closed (you stop recording) → volume is restored

It follows whether the microphone is **open**, not whether you are **speaking**, so pauses while you think don't let the music back in.

### Requirements

- Windows 10/11, Windows PowerShell 5.1 (built in)
- Claude Desktop for Windows (Microsoft Store / MSIX version)

No install, no dependencies, no admin rights, no system settings or registry changes (it only reads one registry key).

### Usage

Run it once (keep it in the background):

```powershell
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File .\claude-voice-duck.ps1
```

Options:

```powershell
# duck to 10% instead of the default 20%
.\claude-voice-duck.ps1 -DuckPercent 10
```

Start automatically at login (and remove it again):

```powershell
.\install-startup.ps1 -DuckPercent 20
.\install-startup.ps1 -Uninstall
```

Stop it: end the `powershell.exe` process in Task Manager (or `Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ? CommandLine -match 'claude-voice-duck' | % { Stop-Process $_.ProcessId }`).

### Using it with other apps

Pass the app's key name from the registry with `-MicKey`. Packaged apps are listed directly under  
`HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone`,  
classic `.exe` apps under `...\microphone\NonPackaged` (path separators are written as `#`, e.g. `C:#Program Files#App#app.exe`).

### Limitations

- It changes the **master** volume, so every sound drops, including Claude's own. It does not duck only the music player.
- If you change the volume yourself while it's ducked, it will be reset to the pre-recording level afterwards.
- If the script is force-killed while ducked, the volume stays low until you raise it.
- If the Claude Desktop package name differs on your machine, use `-MicKey` as above.

### License

MIT

---

## 中文

**Claude Desktop** 开始语音输入（录音）时，自动压低系统音量，录音结束后恢复。适合边放音乐边工作，又不想音乐被语音输入录进去的人。

微信有这个效果，是因为 Windows 有"通信时自动降低其他声音"的设置（`mmsys.cpl` → 通信选项卡），但它只对把麦克风标记为"通信"类型的程序生效。Claude Desktop 没有这样标记，所以这个设置对它没用。这个脚本就是补上这一块。

### 原理

Windows 会在注册表（`CapabilityAccessManager\ConsentStore\microphone`）里记录哪些程序正在用麦克风。程序占用麦克风期间，它的 `LastUsedTimeStop` 为 `0`。脚本每 200 毫秒检查一次：

- 麦克风被打开（你点了录音）→ 系统音量降到当前音量的 `DuckPercent`%
- 麦克风被关闭（你结束录音）→ 恢复原来的音量

它判断的是麦克风**有没有打开**，而不是你**有没有在说话**，所以你停顿、思考的时候，音乐也不会回来。

### 要求

- Windows 10/11，自带的 Windows PowerShell 5.1
- Windows 版 Claude Desktop（Microsoft Store / MSIX 版本）

不用安装，没有依赖，不需要管理员权限，不修改系统设置和注册表（只读取一个注册表项）。

### 用法

运行一次，让它留在后台：

```powershell
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File .\claude-voice-duck.ps1
```

可选参数：

```powershell
# 降到 10%（默认 20%）
.\claude-voice-duck.ps1 -DuckPercent 10
```

开机自动运行（以及取消）：

```powershell
.\install-startup.ps1 -DuckPercent 20
.\install-startup.ps1 -Uninstall
```

停止：在任务管理器里结束对应的 `powershell.exe` 进程即可。

### 用在别的程序上

用 `-MicKey` 传入该程序在注册表里的名字。商店版程序直接列在  
`HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone` 下，  
普通 `.exe` 程序在 `...\microphone\NonPackaged` 下（路径里的斜杠显示为 `#`，例如 `C:#Program Files#App#app.exe`）。

### 局限

- 调的是**系统总音量**，所有声音都会变小，包括 Claude 自己的提示音，不能只压低音乐播放器。
- 压低期间如果你自己调了音量，结束后会被重置回录音前的音量。
- 如果脚本在压低期间被强制结束，音量会一直保持在低位，需要手动调回。
- 如果你电脑上 Claude Desktop 的包名不同，请按上面的方法用 `-MicKey` 指定。

### 许可

MIT
