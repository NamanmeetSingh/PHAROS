# PHAROS - Complete Setup & Deployment Guide

## Quick Start

### 1. Prerequisites
- **Flutter**: 3.1.0 or higher
- **Android SDK**: API 26+ (minimum), API 34+ (target)
- **Gradle**: 7.0+
- **JDK**: 11 or higher
- **Device/Emulator**: Android phone with:
  - Call capability (real device recommended for testing)
  - Microphone access
  - At least 500MB free storage

### 2. Project Setup

#### Clone or Initialize
```bash
cd /path/to/PHAROS
flutter clean
flutter pub get
```

#### Generate Build Files
```bash
# iOS (optional for now)
cd ios
pod install
cd ..

# Java/Kotlin files
flutter pub run build_runner build
```

### 3. Configure Android Manifest

The AndroidManifest.xml has been configured with all required permissions:

**Core Permissions:**
- `RECORD_AUDIO` - Microphone access
- `READ_PHONE_STATE` - Call state detection
- `FOREGROUND_SERVICE` - Background service
- `FOREGROUND_SERVICE_MICROPHONE` - Microphone service type (Android 12+)
- `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` - File access
- `INTERNET` - Optional for future server communication

**Services:**
- `BackgroundService` - Foreground service for audio monitoring
- Configured with `microphone` foreground service type

### 4. Android Studio Configuration

#### Create/Update build.gradle
The `android/app/build.gradle` includes:
- `minSdkVersion 26` (required for foreground services)
- `targetSdkVersion 34` (latest Android version)
- `compileSdkVersion 34`
- Proper Kotlin configuration
- Dependency management for background service

#### Important: Update local.properties
Create `android/local.properties` with:
```properties
sdk.dir=/path/to/Android/sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=release
flutter.versionCode=1
flutter.versionName=1.0.0
```

### 5. Configure Permissions (Runtime)

The app handles runtime permissions via `permission_handler`:
1. Microphone permission
2. Phone state permission

Grant these when prompted on first app launch.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         PHAROS Main App                 │
│  (lib/main.dart - PharosApp)            │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
   ┌────▼─────┐          ┌────▼─────┐
   │ Phone     │          │   Audio  │
   │ State     │          │ Chunking │
   │ Listener  │          │ Engine   │
   └────┬─────┘          └────┬─────┘
        │                     │
        │     ┌───────────────┤
        │     │               │
        └─────┼────┬──────────┤
              │    │          │
              ▼    ▼          ▼
         ┌─────────────────┐
         │ Activity Log    │
         │ Service         │
         └────────┬────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
    ┌───▼────┐          ┌────▼────┐
    │  UI    │          │  WAV    │
    │Display │          │ Chunks  │
    └────────┘          └─────────┘

┌──────────────────────────────────────────┐
│    Android Foreground Service            │
│    (BackgroundService)                   │
└──────────────────────────────────────────┘
```

## Installation & Running

### Debug Build
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# With verbose logging
flutter run -v

# Hot reload enabled
# Press 'r' to reload during development
```

### Release Build
```bash
# Build APK
flutter build apk --release

# Build AAB (for Google Play)
flutter build appbundle --release

# Output locations:
# APK: build/app/outputs/apk/release/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

### Testing Installation
```bash
# Install APK to device
adb install build/app/outputs/apk/release/app-release.apk

# Run app
adb shell am start -n com.pharos.app/.MainActivity

# View logs
adb logcat | grep "PHAROS\|pharos"
```

## Key Files Explained

### Core Services

**1. Phone State Listener** (`lib/services/phone_state_listener.dart`)
- Monitors: IDLE, RINGING, IN_CALL
- Triggers: Audio engine start/stop
- Callbacks: onCallStarted, onCallEnded
- Logging: All state changes to activity log

**2. Audio Chunking Engine** (`lib/services/audio_chunking_engine.dart`)
- Input: Microphone stream (16kHz, 16-bit, Mono)
- Processing: Rolling buffer + silence detection
- Threshold: -40dB silence for 800ms
- Output: WAV files saved to `/PHAROS_CHUNKS/`
- States: Sleeping → Active → Processing → Sleeping

**3. Activity Log Service** (`lib/services/activity_log_service.dart`)
- Categories: [TEL], [MIC], [VAD], [I/O], [ENG], [ERR], [INF]
- Retention: Max 500 events (FIFO)
- Purpose: Track all system events with timestamps

### UI Components

**1. Status Dashboard** (`lib/widgets/status_dashboard.dart`)
- Phone State: Idle / Ringing / In Call
- Engine State: Sleeping / Active / Processing
- Microphone Level: Real-time dB reading
- Status Cards: Visual indicators with color coding

**2. Audio Visualizer** (`lib/widgets/audio_visualizer.dart`)
- Circular Pulse: Radius changes with decibel level
- Waveform: Bar graph with wave animation
- Colors: Neon green when active, gray when idle
- Updates: Real-time reactive to microphone input

**3. Activity Log Widget** (`lib/widgets/activity_log_widget.dart`)
- Terminal Style: Monospace font, neon colors
- Auto-scroll: Latest events visible at bottom
- Color Coding: By event category
- History: Displays last 30 events by default

## Testing Scenarios

### Scenario 1: Manual Engine Override (Best for Testing)
1. Launch app
2. Toggle "MANUAL OVERRIDE" switch ON
3. Speak into device microphone
4. Observe:
   - Activity log shows [MIC] events
   - Visualizer responds to audio
   - Silence after 800ms triggers chunk save
5. Check files: `/data/data/com.pharos.app/files/PHAROS_CHUNKS/`

**Commands to verify:**
```bash
# List saved chunks
adb shell ls -l /data/data/com.pharos.app/files/PHAROS_CHUNKS/

# Pull a chunk to inspect
adb pull /data/data/com.pharos.app/files/PHAROS_CHUNKS/pharos_chunk_0001.wav

# Verify WAV format
file pharos_chunk_0001.wav
hexdump -C pharos_chunk_0001.wav | head
```

### Scenario 2: Auto-Trigger with Phone Call (Real Device Only)
1. Launch app on real Android device
2. Make an incoming or outgoing call
3. Observe:
   - Phone state changes to "In Call"
   - Engine automatically starts
   - Activity log shows: [TEL] Call detected. Starting engine...
   - Audio chunks saved during call
   - Engine stops when call ends

### Scenario 3: Permission Testing
1. Revoke permissions: Settings → Apps → PHAROS → Permissions
2. Launch app
3. Grant permissions when prompted
4. Verify app functions normally

### Scenario 4: Background Service Testing
1. Launch app with manual override ON
2. Press home button to background
3. Return to app after 30 seconds
4. Verify:
   - Foreground notification visible: "PHAROS: Actively monitoring call audio"
   - Audio recording continued in background
   - New chunks created while backgrounded

## Debugging

### Enable Verbose Logging
```bash
# In main.dart, the Logger package provides detailed logs
# View in terminal:
flutter run -v

# Or via adb:
adb logcat -s "flutter"
```

### Access Activity Log
- In app: Scrollable terminal widget shows all events
- Colors indicate event type:
  - 🟢 Green [TEL] - Telephony
  - 🔵 Blue [MIC] - Microphone
  - 🟠 Orange [VAD] - Voice Activity
  - 🟣 Magenta [I/O] - File I/O
  - 🔷 Cyan [ENG] - Engine
  - 🔴 Red [ERR] - Errors
  - ⚪ Gray [INF] - Info

### Check WAV Files
```bash
# Connect to shell
adb shell

# Navigate to chunks directory
cd /data/data/com.pharos.app/files/PHAROS_CHUNKS/

# List files
ls -lh

# Check file details
file pharos_chunk_*.wav

# Exit shell
exit
```

### Common Issues & Solutions

**Issue: App crashes on launch**
```
Solution: 
1. flutter clean
2. flutter pub get
3. flutter run --verbose
4. Check permissions in system settings
```

**Issue: No audio chunks being saved**
```
Solution:
1. Check microphone permission is granted
2. Use manual override to test
3. Speak loudly for at least 2 seconds, then pause
4. Check activity log for [I/O] events
```

**Issue: Foreground service notification not showing**
```
Solution:
1. Verify minSdkVersion >= 26 in build.gradle
2. Check notification channel configuration
3. Verify FOREGROUND_SERVICE permission in manifest
4. On Android 12+, also need FOREGROUND_SERVICE_MICROPHONE
```

**Issue: Phone state not detected**
```
Solution:
1. Grant READ_PHONE_STATE permission
2. Use real device (emulator may not support call state)
3. Check if phone state listener is started
4. Verify permission in system settings
```

## Performance Optimization

### Memory Management
- Rolling buffer instead of continuous recording
- Automatic chunk saving on silence (prevents buffer overflow)
- FIFO activity log with 500 event limit
- Efficient PCM to WAV conversion

### Battery Usage
- Background service only runs during calls
- Foreground service prevents aggressive termination
- Efficient microphone sampling at 16kHz (not maximum)
- Idle state minimizes power consumption

### Storage Management
- Chunks auto-saved to local app directory
- WAV format efficient for neural network processing
- Silence-based chunking reduces file count
- Consider implementing cloud sync for large deployments

## Integration with Backend

### Future Server Connection
Once ready to integrate with backend:

1. **Upload Chunks**
   ```dart
   // In audio_chunking_engine.dart, after _saveAudioChunk():
   await _uploadChunkToServer(filePath);
   ```

2. **Endpoint Format**
   ```
   POST /api/v1/chunks
   Headers: {
     'Authorization': 'Bearer <token>',
     'Content-Type': 'application/octet-stream',
   }
   Body: WAV file bytes
   ```

3. **Response Handling**
   ```dart
   // Log ML analysis results
   activityLog.logInfo('Analysis: ${response.deepfakeScore}% deepfake risk');
   ```

## Deployment Checklist

- [ ] Flutter version 3.1+
- [ ] Android minSdkVersion 26, targetSdkVersion 34
- [ ] All permissions in AndroidManifest.xml
- [ ] Foreground service configured
- [ ] Runtime permissions handled
- [ ] WAV chunking engine working
- [ ] Phone state listener active
- [ ] UI responsive and dark mode applied
- [ ] Activity log functional
- [ ] Manual override toggle works
- [ ] Audio files saved correctly
- [ ] App survives backgrounding
- [ ] Error handling complete
- [ ] Logging comprehensive
- [ ] Release build tested on device

## Support & Resources

### Documentation
- Flutter: https://flutter.dev/docs
- Android Foreground Services: https://developer.android.com/guide/components/foreground-services
- WAV Format: https://en.wikipedia.org/wiki/WAV
- Android Permissions: https://developer.android.com/guide/topics/permissions/overview

### Flutter Packages Used
- `record`: https://pub.dev/packages/record
- `flutter_background_service`: https://pub.dev/packages/flutter_background_service
- `phone_state`: https://pub.dev/packages/phone_state
- `permission_handler`: https://pub.dev/packages/permission_handler

### Contact & Feedback
For issues, feature requests, or questions, refer to project documentation or contact the PHAROS team.

---

**Last Updated**: 2026-05-04
**Version**: 1.0.0
**Status**: Production Ready
