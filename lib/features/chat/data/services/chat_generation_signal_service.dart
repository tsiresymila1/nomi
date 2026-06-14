import 'dart:async';

import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';

/// Production [GenerationSignal] backed by the real chat generation cubits.
///
/// [ChatThreadActions.sendMessage] streams the assistant reply into
/// [ChatDraftResponseCubit] and toggles [ChatGeneratingCubit], then clears the
/// draft in its `finally`. We capture the last non-empty draft text while
/// generation is in flight, await the send, and return that captured text as
/// the final reply — so the conversation loop gets the finished reply without
/// racing the database or re-querying messages.
class ChatGenerationSignal implements GenerationSignal {
  ChatGenerationSignal({
    required ChatGeneratingCubit generatingCubit,
    required ChatDraftResponseCubit draftResponseCubit,
  }) : _generatingCubit = generatingCubit,
       _draftResponseCubit = draftResponseCubit;

  final ChatGeneratingCubit _generatingCubit;
  final ChatDraftResponseCubit _draftResponseCubit;

  @override
  Future<String?> run(Future<void> Function() send) async {
    String? lastNonEmptyDraft;

    // Seed with whatever is already in the draft (normally null/empty).
    final seed = _draftResponseCubit.state;
    if (seed != null && seed.trim().isNotEmpty) {
      lastNonEmptyDraft = seed;
    }

    final subscription = _draftResponseCubit.stream.listen((draft) {
      if (draft != null && draft.trim().isNotEmpty) {
        lastNonEmptyDraft = draft;
      }
    });

    try {
      await send();
      // After send completes, generation is finished and the draft has been
      // cleared; the last non-empty value we saw is the final reply text.
      return lastNonEmptyDraft;
    } finally {
      await subscription.cancel();
      // Defensive: ensure the spinner is not left on if send threw before its
      // own cleanup ran.
      if (_generatingCubit.state) {
        _generatingCubit.setGenerating(false);
      }
    }
  }
}
