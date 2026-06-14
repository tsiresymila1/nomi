import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';

/// Full-screen hands-free voice conversation UI. A central animated orb reflects
/// the loop phase (listening / transcribing / thinking / speaking), the live
/// transcript is shown below it, and a large close button exits. Tapping the orb
/// stops listening now or barges in while speaking.
///
/// The cubit is provided by the route; this page just drives [enter] on mount
/// and [exit] on dismount, and renders [VoiceConversationState].
class VoiceConversationPage extends StatefulWidget {
  const VoiceConversationPage({super.key});

  @override
  State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VoiceConversationCubit>().enter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Always tear the session down when leaving the page.
        context.read<VoiceConversationCubit>().exit();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: BlocBuilder<VoiceConversationCubit, VoiceConversationState>(
            builder: (context, state) {
              return Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        tooltip: 'Close voice mode',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () =>
                            context.read<VoiceConversationCubit>().onTap(),
                        behavior: HitTestBehavior.opaque,
                        child: _VoiceOrb(
                          phase: state.phase,
                          micLevel: state.micLevel,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      _phaseLabel(state.phase),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      child: Text(
                        state.partialTranscript,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32, top: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedStop,
                        size: 22,
                      ),
                      label: const Text('Stop'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _phaseLabel(VoiceConversationPhase phase) => switch (phase) {
    VoiceConversationPhase.idle => 'Starting…',
    VoiceConversationPhase.listening => 'Listening…',
    VoiceConversationPhase.transcribing => 'Transcribing…',
    VoiceConversationPhase.thinking => 'Thinking…',
    VoiceConversationPhase.speaking => 'Speaking… (tap to interrupt)',
  };
}

/// Animated orb that pulses/scales differently per phase. While listening it
/// also reacts to the live mic level for an immediate sense of feedback.
class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.phase,
    required this.micLevel,
    required this.color,
  });

  final VoiceConversationPhase phase;
  final double micLevel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Mic level (0..1) nudges the listening orb size for live feedback.
    final levelScale = phase == VoiceConversationPhase.listening
        ? 1.0 + (micLevel.clamp(0.0, 1.0) * 0.25)
        : 1.0;

    final orb = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: levelScale,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.65)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 48,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: HugeIcon(icon: _phaseIcon, size: 56, color: Colors.white),
        ),
      ),
    );

    // Phase-specific looping animation, keyed so it restarts on phase change.
    return switch (phase) {
      VoiceConversationPhase.thinking =>
        orb
            .animate(key: const ValueKey('thinking'), onPlay: (c) => c.repeat())
            .rotate(duration: 2400.ms),
      VoiceConversationPhase.speaking =>
        orb
            .animate(
              key: const ValueKey('speaking'),
              onPlay: (c) => c.repeat(reverse: true),
            )
            .scaleXY(begin: 0.94, end: 1.08, duration: 600.ms),
      VoiceConversationPhase.listening =>
        orb
            .animate(
              key: const ValueKey('listening'),
              onPlay: (c) => c.repeat(reverse: true),
            )
            .scaleXY(begin: 0.98, end: 1.04, duration: 1200.ms),
      _ => orb,
    };
  }

  List<List<dynamic>> get _phaseIcon => switch (phase) {
    VoiceConversationPhase.speaking => HugeIcons.strokeRoundedVolumeHigh,
    VoiceConversationPhase.thinking => HugeIcons.strokeRoundedLoading03,
    _ => HugeIcons.strokeRoundedMic02,
  };
}
