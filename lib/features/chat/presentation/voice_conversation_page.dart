import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';
import 'package:gena/features/chat/presentation/widgets/voice_crystal_orb.dart';

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
                        child: VoiceCrystalOrb(
                          phase: state.phase,
                          micLevel: state.micLevel,
                          accentColor: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  VoiceConversationStatus(
                    state: state,
                    onCancelTurn: () => context
                        .read<VoiceConversationCubit>()
                        .cancelCurrentTurn(),
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
}

class VoiceConversationStatus extends StatelessWidget {
  const VoiceConversationStatus({
    super.key,
    required this.state,
    required this.onCancelTurn,
  });

  final VoiceConversationState state;
  final Future<void> Function() onCancelTurn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            _voicePhaseLabel(state.phase),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (state.errorMessage case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Text(
              state.partialTranscript,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (state.canCancelTurn)
          TextButton.icon(
            onPressed: onCancelTurn,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel current turn'),
          )
        else
          TextButton.icon(onPressed: () {}, label: const Text('')),
      ],
    );
  }
}

String _voicePhaseLabel(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.idle => 'Starting…',
  VoiceConversationPhase.listening => 'Listening…',
  VoiceConversationPhase.transcribing => 'Transcribing… (tap to cancel)',
  VoiceConversationPhase.thinking => 'Thinking… (tap to cancel)',
  VoiceConversationPhase.speaking => 'Speaking… (tap to interrupt)',
};
