import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';

/// Press-and-hold microphone button for on-device voice input.
///
/// Hold to record (a timer and recording indicator appear); release to stop and
/// transcribe; slide far enough away while holding to cancel and discard. While
/// transcribing a spinner is shown. The widget stays thin — the actual
/// record→transcribe flow lives in [VoiceInputCubit].
class ChatInputVoiceButton extends StatefulWidget {
  const ChatInputVoiceButton({
    super.key,
    required this.cubit,
    required this.enabled,
  });

  final VoiceInputCubit cubit;
  final bool enabled;

  @override
  State<ChatInputVoiceButton> createState() => _ChatInputVoiceButtonState();
}

class _ChatInputVoiceButtonState extends State<ChatInputVoiceButton> {
  static const double _cancelDragThreshold = 80;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _willCancel = false;

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  Future<void> _onLongPressStart() async {
    if (!widget.enabled) return;
    setState(() => _willCancel = false);
    _startTimer();
    await widget.cubit.startRecording();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final willCancel = details.offsetFromOrigin.dy < -_cancelDragThreshold;
    if (willCancel != _willCancel) {
      setState(() => _willCancel = willCancel);
    }
  }

  Future<void> _onLongPressEnd() async {
    _stopTimer();
    if (_willCancel) {
      await widget.cubit.cancelRecording();
    } else {
      await widget.cubit.stopAndTranscribe();
    }
    if (mounted) setState(() => _willCancel = false);
  }

  String _formatElapsed(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _VoiceInputStateBuilder(
      cubit: widget.cubit,
      builder: (context, state) {
        if (state.isTranscribing) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final recording = state.isRecording;

        return GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: (_) => _onLongPressEnd(),
          onLongPressCancel: () {
            _stopTimer();
            widget.cubit.cancelRecording();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recording) ...[
                Text(
                  _willCancel ? 'Release to cancel' : _formatElapsed(_elapsed),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _willCancel
                        ? colorScheme.error
                        : colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: widget.enabled ? () {} : null,
                tooltip: 'Hold to record voice input',
                icon: HugeIcon(
                  icon: recording
                      ? HugeIcons.strokeRoundedRecord
                      : HugeIcons.strokeRoundedMic02,
                  size: 25,
                  color: recording
                      ? (_willCancel ? colorScheme.error : colorScheme.primary)
                      : colorScheme.primary,
                ),
                splashRadius: 16,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tiny helper so the button rebuilds on [VoiceInputCubit] state changes without
/// requiring a `BlocProvider` ancestor (the cubit is passed in directly).
class _VoiceInputStateBuilder extends StatelessWidget {
  const _VoiceInputStateBuilder({required this.cubit, required this.builder});

  final VoiceInputCubit cubit;
  final Widget Function(BuildContext context, VoiceInputState state) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VoiceInputState>(
      stream: cubit.stream,
      initialData: cubit.state,
      builder: (context, snapshot) {
        return builder(context, snapshot.data ?? cubit.state);
      },
    );
  }
}
