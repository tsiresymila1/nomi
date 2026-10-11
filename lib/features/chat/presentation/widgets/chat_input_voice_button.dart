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
  Future<void>? _recordingStart;
  Duration _elapsed = Duration.zero;
  bool _willCancel = false;
  bool _finishing = false;

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 100));
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
    final start = widget.cubit.startRecording();
    _recordingStart = start;
    await start;
    if (!widget.cubit.state.isRecording) {
      _stopTimer();
      if (mounted) setState(() {});
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final willCancel = details.offsetFromOrigin.dy < -_cancelDragThreshold;
    if (willCancel != _willCancel) {
      setState(() => _willCancel = willCancel);
    }
  }

  Future<void> _finishRecording({required bool cancel}) async {
    if (_finishing) return;
    _finishing = true;
    _stopTimer();
    try {
      await _recordingStart;
      if (cancel || _willCancel) {
        await widget.cubit.cancelRecording();
      } else {
        await widget.cubit.stopAndTranscribe();
      }
    } finally {
      _recordingStart = null;
      _finishing = false;
      if (mounted) setState(() => _willCancel = false);
    }
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
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: (_) => _finishRecording(cancel: false),
          onLongPressCancel: () {
            unawaited(_finishRecording(cancel: true));
          },
          child: Tooltip(
            message: 'Hold to record voice input',
            triggerMode: TooltipTriggerMode.manual,
            child: Semantics(
              button: true,
              enabled: widget.enabled,
              label: 'Hold to record voice input',
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recording) ...[
                      _VoiceWaveform(
                        level: state.micLevel,
                        color: _willCancel
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _willCancel
                            ? 'Release to cancel'
                            : _formatElapsed(_elapsed),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _willCancel
                              ? colorScheme.error
                              : colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    HugeIcon(
                      icon: recording
                          ? HugeIcons.strokeRoundedRecord
                          : HugeIcons.strokeRoundedMic02,
                      size: 25,
                      color: widget.enabled
                          ? recording
                                ? (_willCancel
                                      ? colorScheme.error
                                      : colorScheme.primary)
                                : colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.level, required this.color});

  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = level.clamp(0.08, 1.0);
    const weights = <double>[0.42, 0.72, 1, 0.68, 0.46];
    return SizedBox(
      width: 24,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final weight in weights)
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: 3,
              height: 4 + (14 * normalized * weight),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
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
