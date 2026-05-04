import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AudioVisualizer extends StatefulWidget {
  final double decibel;
  final bool isActive;

  const AudioVisualizer({
    Key? key,
    required this.decibel,
    required this.isActive,
  }) : super(key: key);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Normalize decibel to a 0-1 scale for visualization
    // Assuming range from -80 to 0 dB
    final normalizedDb = ((widget.decibel + 80) / 80).clamp(0.0, 1.0);
    final pulseScale = 1.0 + (normalizedDb * 0.5);

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: widget.isActive
              ? [
                  const Color(0xFF00FF88).withOpacity(0.3),
                  const Color(0xFF0066FF).withOpacity(0.1),
                ]
              : [
                  const Color(0xFF444444).withOpacity(0.2),
                  const Color(0xFF222222).withOpacity(0.1),
                ],
        ),
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFF00FF88)
              : const Color(0xFF444444),
          width: 2,
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: pulseScale).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
        ),
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: widget.isActive
                    ? [
                        const Color(0xFF00FF88),
                        const Color(0xFF0066FF),
                      ]
                    : [
                        const Color(0xFF666666),
                        const Color(0xFF333333),
                      ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isActive ? 'LISTENING' : 'IDLE',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.decibel.toStringAsFixed(1)} dB',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaveformVisualizer extends StatelessWidget {
  final double decibel;
  final bool isActive;

  const WaveformVisualizer({
    Key? key,
    required this.decibel,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final normalizedDb = ((decibel + 80) / 80).clamp(0.0, 1.0);
    final barCount = 20;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(barCount, (index) {
        // Create a wave pattern
        final waveHeight = (Math.sin((index + DateTime.now().millisecondsSinceEpoch / 100) * 0.3) + 1) / 2;
        final height = 20.0 + (waveHeight * normalizedDb * 60);

        return Container(
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: isActive
                ? Color.lerp(
                    const Color(0xFF0066FF),
                    const Color(0xFF00FF88),
                    (index / barCount),
                  )
                : const Color(0xFF444444),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class Math {
  static double sin(double x) => double.parse(
      ((_sin(x)).toStringAsFixed(10)).trimEnd()); // trim trailing zeros

  static double _sin(double x) {
    x = x % 6.283185307179586; // modulo 2π
    if (x > 3.141592653589793) x = 6.283185307179586 - x;
    const p1 = 1.5707963267948966;
    const p2 = -0.21460183660255172;
    const p3 = 0.08693295673236083;
    const p4 = -0.12968517707529573;
    final y = p1 + x * (p2 + x * (p3 + x * p4));
    return y * x * (p1 + x * (p2 + x * (p3 + x * p4)));
  }
}
