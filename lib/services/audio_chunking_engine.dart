import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'activity_log_service.dart';

enum AudioChunkingEngineState {
  sleeping,
  active,
  processing,
}

class AudioChunk {
  final String filePath;
  final DateTime createdAt;
  final int durationMs;
  final int fileSize;

  AudioChunk({
    required this.filePath,
    required this.createdAt,
    required this.durationMs,
    required this.fileSize,
  });
}

class AudioChunkingEngine extends ChangeNotifier {
  final Logger _logger = Logger();
  final ActivityLogService activityLog;

  final Record _audioRecorder = Record();
  
  AudioChunkingEngineState _state = AudioChunkingEngineState.sleeping;
  final List<int> _audioBuffer = [];
  
  late Directory _documentsDir;
  int _chunkCounter = 0;
  
  // Configuration
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitDepth = 16;
  static const int silenceThresholdDb = -40;
  static const int silenceDurationMs = 800;
  
  // State tracking
  DateTime? _lastSoundTime;
  int _currentChunkSize = 0;
  double _currentDecibel = 0;
  
  // Streaming and async management
  StreamSubscription? _recordingSubscription;

  AudioChunkingEngineState get state => _state;
  double get currentDecibel => _currentDecibel;
  bool get isActive => _state == AudioChunkingEngineState.active;

  AudioChunkingEngine({required this.activityLog});

  /// Initialize the audio chunking engine
  Future<void> initialize() async {
    try {
      _documentsDir = await getApplicationDocumentsDirectory();
      final pharosDir = Directory('${_documentsDir.path}/PHAROS_CHUNKS');
      
      if (!await pharosDir.exists()) {
        await pharosDir.create(recursive: true);
      }

      activityLog.logInfo('Audio chunking engine initialized');
      notifyListeners();
    } catch (e) {
      activityLog.logError('Failed to initialize audio engine: $e');
      _logger.e('Error initializing audio engine: $e');
    }
  }

  /// Start the audio chunking engine
  Future<void> start() async {
    if (_state == AudioChunkingEngineState.active) {
      _logger.w('Audio engine is already active');
      return;
    }

    try {
      _state = AudioChunkingEngineState.active;
      _audioBuffer.clear();
      _chunkCounter = 0;
      _lastSoundTime = DateTime.now();
      _currentChunkSize = 0;

      activityLog.logEngine('Audio chunking engine started');
      activityLog.logMicrophone('Audio buffer started');
      notifyListeners();

      // Start recording
      await _startRecording();
    } catch (e) {
      activityLog.logError('Failed to start audio engine: $e');
      _state = AudioChunkingEngineState.sleeping;
      _logger.e('Error starting audio engine: $e');
      notifyListeners();
    }
  }

  /// Stop the audio chunking engine
  Future<void> stop() async {
    if (_state == AudioChunkingEngineState.sleeping) {
      return;
    }

    try {
      await _recordingSubscription?.cancel();
      await _audioRecorder.stop();

      // Save any remaining audio in buffer
      if (_audioBuffer.isNotEmpty) {
        await _saveAudioChunk(_audioBuffer);
      }

      _state = AudioChunkingEngineState.sleeping;
      _audioBuffer.clear();
      activityLog.logEngine('Audio chunking engine stopped');
      notifyListeners();
    } catch (e) {
      activityLog.logError('Error stopping audio engine: $e');
      _logger.e('Error stopping audio engine: $e');
    }
  }

  /// Start recording from the microphone
  Future<void> _startRecording() async {
    try {
      // Check if recording is already active
      if (await _audioRecorder.isRecording()) {
        _logger.w('Recording is already active');
        return;
      }

      final recordStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bit,
          sampleRate: sampleRate,
          numChannels: channels,
        ),
      );

      _recordingSubscription = recordStream.listen(
        (data) {
          _processAudioChunk(data);
        },
        onError: (error) {
          _logger.e('Recording error: $error');
          activityLog.logError('Recording error: $error');
        },
      );
    } catch (e) {
      _logger.e('Error starting recording: $e');
      activityLog.logError('Failed to start recording: $e');
    }
  }

  /// Process incoming audio chunk from the microphone
  void _processAudioChunk(Uint8List data) {
    try {
      _state = AudioChunkingEngineState.processing;

      // Add to buffer
      _audioBuffer.addAll(data);
      _currentChunkSize += data.length;

      // Calculate decibel level (simplified)
      _currentDecibel = _calculateDecibel(data);
      
      // Check if we've crossed silence threshold and silence duration
      if (_currentDecibel > silenceThresholdDb) {
        _lastSoundTime = DateTime.now();
      }

      // Check for silence duration
      final now = DateTime.now();
      if (_lastSoundTime != null &&
          now.difference(_lastSoundTime!).inMilliseconds > silenceDurationMs) {
        if (_audioBuffer.isNotEmpty) {
          _saveAudioChunkAsync(_audioBuffer.toList());
          _audioBuffer.clear();
          _currentChunkSize = 0;
          _lastSoundTime = DateTime.now();
        }
      }

      _state = AudioChunkingEngineState.active;
      notifyListeners();
    } catch (e) {
      _logger.e('Error processing audio chunk: $e');
      activityLog.logError('Error processing audio: $e');
    }
  }

  /// Save audio chunk asynchronously
  Future<void> _saveAudioChunkAsync(List<int> audioData) async {
    try {
      _state = AudioChunkingEngineState.processing;
      notifyListeners();

      await _saveAudioChunk(audioData);

      _state = AudioChunkingEngineState.active;
      notifyListeners();
    } catch (e) {
      _logger.e('Error saving audio chunk: $e');
      activityLog.logError('Failed to save audio chunk: $e');
    }
  }

  /// Save audio chunk as WAV file
  Future<void> _saveAudioChunk(List<int> audioData) async {
    try {
      if (audioData.isEmpty) return;

      _chunkCounter++;
      final chunkName = 'pharos_chunk_${_chunkCounter.toString().padLeft(4, '0')}.wav';
      final pharosDir = Directory('${_documentsDir.path}/PHAROS_CHUNKS');
      final filePath = '${pharosDir.path}/$chunkName';

      // Create WAV file
      final wavData = _createWavFile(Uint8List.fromList(audioData));
      final file = File(filePath);
      await file.writeAsBytes(wavData);

      final fileSizeKb = (wavData.length / 1024).toStringAsFixed(1);
      activityLog.logIO('Chunk saved: $chunkName (${fileSizeKb}kb)');
      activityLog.logVAD('Silence detected.');

      _logger.i('Audio chunk saved: $chunkName (${fileSizeKb}kb)');
    } catch (e) {
      _logger.e('Error saving audio chunk: $e');
      activityLog.logError('Failed to save chunk: $e');
    }
  }

  /// Create WAV file from PCM audio data
  Uint8List _createWavFile(Uint8List pcmData) {
    final byteRate = sampleRate * channels * (bitDepth ~/ 8);
    final blockAlign = channels * (bitDepth ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buffer = BytesBuilder();

    // RIFF header
    buffer.addByte(0x52); // 'R'
    buffer.addByte(0x49); // 'I'
    buffer.addByte(0x46); // 'F'
    buffer.addByte(0x46); // 'F'

    // File size - 8
    buffer.add(_intToBytes(fileSize, 4));

    // WAVE header
    buffer.addByte(0x57); // 'W'
    buffer.addByte(0x41); // 'A'
    buffer.addByte(0x56); // 'V'
    buffer.addByte(0x45); // 'E'

    // fmt subchunk
    buffer.addByte(0x66); // 'f'
    buffer.addByte(0x6D); // 'm'
    buffer.addByte(0x74); // 't'
    buffer.addByte(0x20); // ' '

    // Subchunk1 size (16 for PCM)
    buffer.add(_intToBytes(16, 4));

    // Audio format (1 for PCM)
    buffer.add(_intToBytes(1, 2));

    // Number of channels
    buffer.add(_intToBytes(channels, 2));

    // Sample rate
    buffer.add(_intToBytes(sampleRate, 4));

    // Byte rate
    buffer.add(_intToBytes(byteRate, 4));

    // Block align
    buffer.add(_intToBytes(blockAlign, 2));

    // Bits per sample
    buffer.add(_intToBytes(bitDepth, 2));

    // data subchunk
    buffer.addByte(0x64); // 'd'
    buffer.addByte(0x61); // 'a'
    buffer.addByte(0x74); // 't'
    buffer.addByte(0x61); // 'a'

    // Subchunk2 size
    buffer.add(_intToBytes(dataSize, 4));

    // Audio data
    buffer.add(pcmData);

    return buffer.toBytes();
  }

  /// Convert integer to little-endian bytes
  List<int> _intToBytes(int value, int numBytes) {
    final bytes = <int>[];
    for (int i = 0; i < numBytes; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  /// Calculate decibel level from audio data (simplified RMS calculation)
  double _calculateDecibel(Uint8List audioData) {
    if (audioData.isEmpty) return -120;

    // Convert byte data to 16-bit samples
    int sum = 0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = (audioData[i] & 0xFF) | ((audioData[i + 1] & 0xFF) << 8);
      sum += sample * sample;
    }

    final rms = (sum / (audioData.length ~/ 2)).toDouble();
    final db = 20 * (rms > 0 ? (rms.log10()) : -120);

    return db.clamp(-120.0, 0.0);
  }

  /// Get engine state description
  String getStateDescription() {
    switch (_state) {
      case AudioChunkingEngineState.sleeping:
        return 'Sleeping';
      case AudioChunkingEngineState.active:
        return 'Active';
      case AudioChunkingEngineState.processing:
        return 'Processing';
    }
  }

  @override
  void dispose() {
    stop();
    _recordingSubscription?.cancel();
    super.dispose();
  }
}
