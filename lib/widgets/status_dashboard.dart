import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/phone_state_listener.dart';
import '../services/audio_chunking_engine.dart';
import 'audio_visualizer.dart';

class StatusDashboard extends StatelessWidget {
  const StatusDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<PhoneStateListener, AudioChunkingEngine>(
      builder: (context, phoneState, audioEngine, _) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PHAROS',
                        style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Voice Phishing Detection System',
                        style: TextStyle(
                          color: const Color(0xFF888888),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: audioEngine.isActive
                          ? const Color(0xFF00FF88).withOpacity(0.2)
                          : const Color(0xFF444444).withOpacity(0.2),
                      border: Border.all(
                        color: audioEngine.isActive
                            ? const Color(0xFF00FF88)
                            : const Color(0xFF444444),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      audioEngine.getStateDescription().toUpperCase(),
                      style: TextStyle(
                        color: audioEngine.isActive
                            ? const Color(0xFF00FF88)
                            : const Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatusCard(
                      title: 'PHONE STATE',
                      value: phoneState.getStateDescription(),
                      icon: '☎',
                      isActive: phoneState.isInCall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatusCard(
                      title: 'ENGINE STATE',
                      value: audioEngine.getStateDescription(),
                      icon: '⚙',
                      isActive: audioEngine.isActive,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Audio Visualizer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    AudioVisualizer(
                      decibel: audioEngine.currentDecibel,
                      isActive: audioEngine.isActive,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Microphone Level: ${audioEngine.currentDecibel.toStringAsFixed(1)} dB',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Waveform
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: WaveformVisualizer(
                  decibel: audioEngine.currentDecibel,
                  isActive: audioEngine.isActive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final bool isActive;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF00FF88).withOpacity(0.05)
            : const Color(0xFF444444).withOpacity(0.05),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00FF88)
              : const Color(0xFF444444),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isActive
                  ? const Color(0xFF00FF88)
                  : const Color(0xFFBBBBBB),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
