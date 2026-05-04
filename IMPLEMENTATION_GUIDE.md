# PHAROS - Complete Flutter Implementation

## Project Overview
PHAROS is a real-time voice phishing and deepfake detection Android app built with Flutter. It monitors microphone input during active phone calls using the "Speakerphone Method" due to Android's restrictions on call recording.

## Architecture

### Core Components

#### 1. **Phone State Listener** (`lib/services/phone_state_listener.dart`)
- Monitors device phone state: IDLE, RINGING, IN_CALL
- Triggers callbacks when call state changes
- Auto-starts/stops the audio chunking engine
- Logs all telephony events to the activity log

#### 2. **Audio Chunking Engine** (`lib/services/audio_chunking_engine.dart`)
- Listens to microphone stream at 16kHz, 16-bit, Mono (PCM)
- Implements rolling buffer with silence detection (>800ms)
- Detects silence threshold at -40dB
- Saves audio chunks as WAV files in app's documents directory
- Tracks current decibel level for UI visualization
- States: Sleeping, Active, Processing

#### 3. **Activity Log Service** (`lib/services/activity_log_service.dart`)
- Tracks system events with categorized logging levels:
  - `[TEL]` - Telephony events
  - `[MIC]` - Microphone events
  - `[VAD]` - Voice Activity Detection
  - `[I/O]` - File I/O operations
  - `[ENG]` - Engine state changes
  - `[ERR]` - Error events
  - `[INF]` - Info events
- Maintains rolling log history (max 500 events)
- Provides real-time notifications via ChangeNotifier

#### 4. **UI Components**
- **Status Dashboard** (`lib/widgets/status_dashboard.dart`)
  - Current phone state display
  - Engine state indicator
  - Microphone level display
  
- **Audio Visualizer** (`lib/widgets/audio_visualizer.dart`)
  - Circular pulsing indicator (active/sleeping)
  - Real-time waveform display
  - Decibel level visualization
  
- **Activity Log Widget** (`lib/widgets/activity_log_widget.dart`)
  - Scrolling terminal-style log display
  - Color-coded events by category
  - Auto-scroll to latest events

#### 5. **Main App** (`lib/main.dart`)
- Initializes all services and permissions
- Sets up foreground service for background operation
- Provides manual override toggle for engine control
- Dark-mode cybersecurity-themed UI

## How It Works

### Workflow

1. **Initialization**
   - Request Microphone and Phone State permissions
   - Initialize audio chunking engine
   - Start phone state listener

2. **Call Detection**
   - Phone state listener detects `CALL_STATE_OFFHOOK`
   - Automatic trigger to start audio recording engine

3. **Audio Processing**
   - Microphone stream feeds into circular buffer
   - Real-time decibel level calculation
   - Silence detection (>800ms at -40dB threshold)

4. **Chunk Generation**
   - When silence is detected, buffer is saved as 16kHz, 16-bit, Mono WAV
   - File naming: `pharos_chunk_XXXX.wav`
   - Stored in `/data/data/com.pharos.app/files/PHAROS_CHUNKS/`
   - Event logged: `[I/O] Chunk saved: pharos_chunk_0001.wav (450kb)`

5. **Call End**
   - Phone state changes to `CALL_STATE_IDLE`
   - Engine automatically stops
   - Remaining buffer saved as final chunk
   - Event logged: `[TEL] Call ended.`

### Audio Format Specifications
- **Sample Rate**: 16,000 Hz
- **Bit Depth**: 16-bit PCM
- **Channels**: Mono (1 channel)
- **Format**: WAV (RIFF)
- **Silence Threshold**: -40 dB
- **Silence Duration**: 800ms (triggers save)

## Android Configuration

### Required Permissions (AndroidManifest.xml)
```xml
<!-- Core Permissions -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Foreground Service
- Required for background microphone access during active calls
- Displays persistent notification: "PHAROS: Actively monitoring call audio"
- Service type: `microphone` (Android 12+)
- Prevents app termination during call monitoring

## Flutter Packages

### Audio & Recording
- `record` - Microphone stream access
- `wav` - WAV file generation

### Background Service
- `flutter_background_service` - Background execution
- `flutter_background_service_android` - Android-specific implementation
- `flutter_local_notifications` - Foreground service notifications

### Telephony
- `phone_state` - Call state detection
- `telephony` - Enhanced phone event access

### Permissions
- `permission_handler` - Permission requests and management

### State Management
- `provider` - Reactive UI updates
- `get_it` - Service locator (optional)

### UI & Animations
- `flutter_animate` - Smooth animations
- `google_fonts` - Typography
- `gradient_animated_button` - Interactive controls

### Utilities
- `path_provider` - File storage paths
- `intl` - Date/time formatting
- `uuid` - Unique identifiers
- `logger` - Debug logging

## Key Features

### 1. **Real-Time Monitoring**
- Continuous microphone monitoring during calls
- Live decibel level visualization
- Waveform display with reactive graphics

### 2. **Intelligent Chunking**
- Silence-based segmentation (no continuous large files)
- Efficient RAM usage with rolling buffer
- Automatic file management

### 3. **Dark Mode Cybersecurity UI**
- Neon green (#00FF88) accent color
- Dark background (#0A0E27)
- Terminal-style activity log
- Professional monitoring aesthetic

### 4. **Robust Background Operation**
- Foreground service ensures background functionality
- Persistent notification during monitoring
- Graceful shutdown on call end
- Survives app state changes

### 5. **Debugging & Monitoring**
- Color-coded activity log with 7 event categories
- Manual engine override for testing
- Real-time status display
- Event history with timestamps

## Build & Run

### Prerequisites
```bash
flutter --version  # Ensure Flutter 3.1+
android:targetSdkVersion >= 31  # For foreground services
```

### Build Steps
```bash
# Install dependencies
flutter pub get

# Generate build files
flutter pub run build_runner build

# Run on Android device
flutter run -d <device_id>

# Build release APK
flutter build apk --release
```

### Testing with Manual Override
1. Tap "MANUAL OVERRIDE" toggle to force start/stop engine
2. Monitor activity log for events
3. Check `/data/data/com.pharos.app/files/PHAROS_CHUNKS/` for WAV files

## Security Considerations

1. **Permissions**: Only request necessary permissions
2. **Storage**: Audio chunks stored in app-private directory
3. **Notification**: Persistent foreground service notification ensures user awareness
4. **Battery**: Efficient microphone monitoring minimizes battery drain
5. **Privacy**: All audio processing happens on-device

## Future Enhancements

1. **ML Integration**: Pass WAV chunks to deepfake detection model
2. **Server Upload**: Queue chunks for backend analysis
3. **Real-Time Scoring**: Display phishing risk indicators
4. **Call Recording**: Option to save full call transcript
5. **Analytics**: Track patterns and statistics
6. **Offline Processing**: On-device ML inference

## Troubleshooting

### Audio Not Recording
- Check microphone permission is granted
- Verify phone state listener is running
- Ensure app is not in restricted/doze mode

### Chunks Not Saving
- Verify write permission to app directory
- Check available storage space
- Ensure phone is not in airplane mode

### Manual Override Not Working
- Check if phone state listener is running
- Restart the app
- Try toggling permission in system settings

### Foreground Service Not Starting
- Verify Android API level >= 26
- Check notification channel setup
- Ensure permissions are granted

## File Structure
```
lib/
├── main.dart
├── services/
│   ├── phone_state_listener.dart
│   ├── audio_chunking_engine.dart
│   └── activity_log_service.dart
└── widgets/
    ├── status_dashboard.dart
    ├── audio_visualizer.dart
    └── activity_log_widget.dart

android/
├── app/src/main/
│   ├── AndroidManifest.xml
│   └── kotlin/com/pharos/app/MainActivity.kt
└── build.gradle
```

---

**Version**: 1.0.0
**Last Updated**: 2026-05-04
**Author**: PHAROS Team
