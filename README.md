# vocorize

**your voice, instantly typed.**

**[download for macos](https://github.com/vocorize/app/releases](https://github.com/vocorize/app/releases/download/beta/Vocorize-v0.2.5.dmg))**

## usage modes

**press-and-hold:** hold hotkey while speaking, release to transcribe

**lock mode:** double-tap hotkey to start recording, single tap to stop and transcribe

---

## technical architecture

built with the [swift composable architecture](https://github.com/pointfreeco/swift-composable-architecture) and powered by [whisperkit](https://github.com/argmaxinc/WhisperKit).

### project structure

- **`app/`** - main app entry point and lifecycle management
- **`clients/`** - core services (recording, transcription, pasteboard, hotkeys)
- **`features/`** - app features (transcription, settings, history)
- **`models/`** - data models and settings
- **`resources/`** - assets, sounds, and language data

---

## build it yourself

### requirements

- apple silicon mac (m1 or later)
- macos 13+ (sonoma recommended)
- xcode 15.x (swift 5.9)

> **important:** don't use xcode 16/swift 6.0 yet - macro compatibility issues.

### setup

1. **install xcode 15**

   - download from [apple developer](https://developer.apple.com/download/all/)
   - extract and move to `/applications`

2. **set xcode 15 as active**

   ```sh
   sudo xcode-select -s /Applications/Xcode_15.app
   ```

3. **clone and build**

   ```sh
   git clone <repo-url>
   cd vocorize
   xcodebuild -resolvePackageDependencies -project Vocorize.xcodeproj -scheme Vocorize
   ```

4. **run in xcode**
   - open `vocorize.xcodeproj`
   - select `vocorize` scheme
   - press `⌘r` to run

### troubleshooting

- **macro errors?** make sure you're using xcode 15.x
- **permission issues?** grant mic and accessibility access on first run
- **switch back to xcode 16?** `sudo xcode-select -s /Applications/Xcode.app`

---

## quick start

1. download and install
2. grant microphone and accessibility permissions
3. on first run, select the recommended model and download it
4. set your hotkey in settings
5. start talking

---

## technical details

- **platform:** macos (apple silicon only)
- **permissions:** microphone + accessibility (to paste text)
- **engine:** whisperkit (runs locally)
- **architecture:** swift composable architecture
- **offline:** no internet required, no data collection

---

## community

questions? ideas? reach out on [twitter](https://twitter.com/okaytanvir).

---

## license

MIT License - see [LICENSE](LICENSE) file for details.
