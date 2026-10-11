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
    duration: const Duration(seconds: 18),
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
            final bounceFrequency = switch (widget.phase) {
              VoiceConversationPhase.listening => 9.0,
              VoiceConversationPhase.speaking => 14.0,
              _ => 2.0,
            };
            final bounce =
                (math.sin((phase * bounceFrequency) - (math.pi / 2)) + 1) * 0.5;
            final bounceAmount = switch (widget.phase) {
              VoiceConversationPhase.listening => 0.025 + (level * 0.065),
              VoiceConversationPhase.speaking => 0.065,
              VoiceConversationPhase.thinking => 0.015,
              _ => 0.008,
            };
            final isVoiceActive =
                widget.phase == VoiceConversationPhase.listening ||
                widget.phase == VoiceConversationPhase.speaking;

            return Transform.translate(
              offset: Offset(
                0,
                isVoiceActive ? -widget.size * 0.012 * bounce : 0,
              ),
              child: Transform.scale(
                key: const ValueKey('voice-crystal-bounce'),
                scale: 1 + (bounce * bounceAmount),
                child: Transform.rotate(
                  key: const ValueKey('voice-crystal-rotation'),
                  angle: phase,
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

    final crystalLight = Color.lerp(accentColor, Colors.white, 0.78)!;
    final crystalMid = Color.lerp(accentColor, Colors.white, 0.38)!;
    final crystalDeep = Color.lerp(accentColor, Colors.black, 0.28)!;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [crystalLight, crystalMid, crystalDeep],
          stops: const [0, 0.52, 1],
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
      crystalLight,
      0.58,
    );
    _paintCloud(
      canvas,
      center.translate(
        math.cos(theta * 1.26 + 4.1) * radius * 0.48,
        math.sin(theta + 3.4) * radius * 0.44,
      ),
      radius * 0.7,
      crystalMid,
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
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0),
            crystalDeep.withValues(alpha: 0),
            crystalDeep.withValues(alpha: 0.48),
          ],
          stops: const [0, 0.58, 1],
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
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            crystalLight.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.9),
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
            accentColor.withValues(alpha: 0),
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

  Color get _phaseTint => Color.lerp(accentColor, Colors.white, switch (phase) {
    VoiceConversationPhase.idle => 0.32,
    VoiceConversationPhase.listening => 0.12,
    VoiceConversationPhase.transcribing => 0.24,
    VoiceConversationPhase.thinking => 0.2,
    VoiceConversationPhase.speaking => 0.08,
  })!;

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
        accentColor: Color(0xFF008F72),
      ),
    ),
  );
}
