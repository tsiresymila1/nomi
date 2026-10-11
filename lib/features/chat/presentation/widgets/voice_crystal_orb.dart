import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';

/// A lightweight, continuously moving crystal orb for hands-free voice mode.
///
/// The animation is rendered with a small number of gradients so it remains
/// smooth on Android while chat inference is using the CPU. During listening,
/// [micLevel] drives the orb's pulse and internal movement.
class VoiceCrystalOrb extends StatefulWidget {
  const VoiceCrystalOrb({
    super.key,
    required this.phase,
    required this.micLevel,
    required this.accentColor,
    this.size = 224,
  });

  final VoiceConversationPhase phase;
  final double micLevel;
  final Color accentColor;
  final double size;

  @override
  State<VoiceCrystalOrb> createState() => _VoiceCrystalOrbState();
}

class _VoiceCrystalOrbState extends State<VoiceCrystalOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = !animationsDisabled;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.micLevel.clamp(0.0, 1.0);

    return Semantics(
      image: true,
      liveRegion: true,
      label: _semanticLabel(widget.phase),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = _controller.value * math.pi * 2;
            final ambientPulse = (math.sin(phase * 2) + 1) * 0.5;
            final voicePulse = widget.phase == VoiceConversationPhase.listening
                ? level * 0.09
                : widget.phase == VoiceConversationPhase.speaking
                ? ambientPulse * 0.045
                : ambientPulse * 0.012;

            return Transform.scale(
              scale: 1 + voicePulse,
              child: SizedBox.square(
                dimension: widget.size,
                child: CustomPaint(
                  key: const ValueKey('voice-crystal-orb'),
                  painter: _VoiceCrystalOrbPainter(
                    progress: _controller.value,
                    phase: widget.phase,
                    micLevel: level,
                    accentColor: widget.accentColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _semanticLabel(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.idle => 'Voice assistant starting',
  VoiceConversationPhase.listening => 'Voice assistant listening',
  VoiceConversationPhase.transcribing => 'Voice assistant transcribing',
  VoiceConversationPhase.thinking => 'Voice assistant thinking',
  VoiceConversationPhase.speaking => 'Voice assistant speaking',
};

class _VoiceCrystalOrbPainter extends CustomPainter {
  const _VoiceCrystalOrbPainter({
    required this.progress,
    required this.phase,
    required this.micLevel,
    required this.accentColor,
  });

  final double progress;
  final VoiceConversationPhase phase;
  final double micLevel;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortestSide * 0.405;
    final theta = progress * math.pi * 2 * _motionSpeed;
    final energy = _energy;

    _paintGlow(canvas, center, radius);

    final sphereBounds = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereBounds));

    final coolBlue = Color.lerp(accentColor, const Color(0xFF258DFF), 0.72)!;
    final cyan = Color.lerp(accentColor, const Color(0xFF8DEBFF), 0.84)!;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4FDFF), Color(0xFF6CD7FF), Color(0xFF1478F2)],
          stops: [0, 0.52, 1],
        ).createShader(sphereBounds),
    );

    _paintCloud(
      canvas,
      center.translate(
        math.cos(theta) * radius * 0.34,
        math.sin(theta * 1.13) * radius * 0.3,
      ),
      radius * (0.72 + energy * 0.1),
      const Color(0xFFFFFFFF),
      0.58,
    );
    _paintCloud(
      canvas,
      center.translate(
        math.cos(theta + 2.2) * radius * 0.4,
        math.sin(theta * 0.82 + 1.4) * radius * 0.38,
      ),
      radius * (0.62 + energy * 0.14),
      cyan,
      0.58,
    );
    _paintCloud(
      canvas,
      center.translate(
        math.cos(theta * 1.26 + 4.1) * radius * 0.48,
        math.sin(theta + 3.4) * radius * 0.44,
      ),
      radius * 0.7,
      coolBlue,
      0.48,
    );
    _paintCloud(
      canvas,
      center.translate(
        math.cos(theta * 0.7 + 5.2) * radius * 0.28,
        math.sin(theta * 1.35 + 0.8) * radius * 0.52,
      ),
      radius * 0.44,
      _phaseTint,
      0.42,
    );

    _paintFacets(canvas, center, radius, theta, sphereBounds);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0x00033E89), Color(0x6600296B)],
          stops: [0, 0.58, 1],
        ).createShader(sphereBounds),
    );

    final highlightBounds = Rect.fromCircle(
      center: center.translate(-radius * 0.32, -radius * 0.38),
      radius: radius * 0.62,
    );
    canvas.drawCircle(
      highlightBounds.center,
      highlightBounds.width / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xBFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(highlightBounds),
    );

    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shortestSide * 0.008
        ..shader = const SweepGradient(
          colors: [
            Color(0xD9FFFFFF),
            Color(0x336FE7FF),
            Color(0xB33690FF),
            Color(0xE6FFFFFF),
          ],
        ).createShader(sphereBounds),
    );
  }

  void _paintGlow(Canvas canvas, Offset center, double radius) {
    final bounds = Rect.fromCircle(center: center, radius: radius * 1.23);
    canvas.drawCircle(
      center,
      radius * 1.23,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _phaseTint.withValues(alpha: 0.24 + _energy * 0.08),
            _phaseTint.withValues(alpha: 0.08),
            _phaseTint.withValues(alpha: 0),
          ],
          stops: const [0.42, 0.72, 1],
        ).createShader(bounds),
    );
  }

  void _paintCloud(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.42),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(bounds),
    );
  }

  void _paintFacets(
    Canvas canvas,
    Offset center,
    double radius,
    double theta,
    Rect sphereBounds,
  ) {
    final drift = math.sin(theta) * radius * 0.1;
    final first = Path()
      ..moveTo(center.dx - radius * 0.9, center.dy + radius * 0.12)
      ..quadraticBezierTo(
        center.dx - radius * 0.1 + drift,
        center.dy - radius * 0.5,
        center.dx + radius * 0.82,
        center.dy - radius * 0.2,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.1,
        center.dy + radius * 0.04,
        center.dx - radius * 0.9,
        center.dy + radius * 0.12,
      );
    canvas.drawPath(
      first,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x70FFFFFF), Color(0x00FFFFFF)],
        ).createShader(sphereBounds),
    );

    final second = Path()
      ..moveTo(center.dx - radius * 0.68, center.dy + radius * 0.7)
      ..quadraticBezierTo(
        center.dx + radius * 0.02 - drift,
        center.dy + radius * 0.05,
        center.dx + radius * 0.72,
        center.dy + radius * 0.48,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.34,
        center.dx - radius * 0.68,
        center.dy + radius * 0.7,
      );
    canvas.drawPath(
      second,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          colors: [
            const Color(0x0018A7FF),
            _phaseTint.withValues(alpha: 0.38),
            const Color(0x00FFFFFF),
          ],
        ).createShader(sphereBounds),
    );
  }

  double get _motionSpeed => switch (phase) {
    VoiceConversationPhase.idle => 0.45,
    VoiceConversationPhase.listening => 0.75 + micLevel * 0.35,
    VoiceConversationPhase.transcribing => 0.8,
    VoiceConversationPhase.thinking => 1.2,
    VoiceConversationPhase.speaking => 1.05,
  };

  double get _energy => switch (phase) {
    VoiceConversationPhase.idle => 0.08,
    VoiceConversationPhase.listening => 0.18 + micLevel * 0.82,
    VoiceConversationPhase.transcribing => 0.42,
    VoiceConversationPhase.thinking => 0.62,
    VoiceConversationPhase.speaking => 0.72,
  };

  Color get _phaseTint => switch (phase) {
    VoiceConversationPhase.idle => const Color(0xFF80BFFF),
    VoiceConversationPhase.listening => const Color(0xFF42E6FF),
    VoiceConversationPhase.transcribing => const Color(0xFF78C8FF),
    VoiceConversationPhase.thinking => const Color(0xFF8B8DFF),
    VoiceConversationPhase.speaking => const Color(0xFF35D6FF),
  };

  @override
  bool shouldRepaint(covariant _VoiceCrystalOrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.micLevel != micLevel ||
      oldDelegate.accentColor != accentColor;
}

@Preview(
  name: 'Voice crystal orb - listening',
  group: 'Voice conversation',
  size: Size(320, 320),
  brightness: Brightness.dark,
)
Widget voiceCrystalOrbPreview() {
  return const Material(
    color: Color(0xFF050A13),
    child: Center(
      child: VoiceCrystalOrb(
        phase: VoiceConversationPhase.listening,
        micLevel: 0.55,
        accentColor: Color(0xFF4A8DFF),
      ),
    ),
  );
}
