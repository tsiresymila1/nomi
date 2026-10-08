import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';

class ChatAttachmentsCubit extends Cubit<List<ChatAttachmentDraft>> {
  ChatAttachmentsCubit({required ChatAttachmentPreparer preparer})
    : _preparer = preparer,
      super(const []);

  final ChatAttachmentPreparer _preparer;
  int _nextDraftId = 0;

  List<PreparedChatAttachment> get readyAttachments => state
      .where(
        (draft) =>
            draft.status == ChatAttachmentDraftStatus.ready &&
            draft.attachment != null,
      )
      .map((draft) => draft.attachment!)
      .toList(growable: false);

  bool get isPreparing =>
      state.any((draft) => draft.status == ChatAttachmentDraftStatus.preparing);

  Future<void> addPath(String rawPath) async {
    final id = 'draft-${++_nextDraftId}';
    final draft = ChatAttachmentDraft(
      id: id,
      originalPath: rawPath,
      displayName: _fileName(rawPath),
      status: ChatAttachmentDraftStatus.preparing,
    );
    emit([...state, draft]);

    try {
      final attachment = await _preparer.prepare(rawPath);
      _replace(
        id,
        draft.copyWith(
          status: ChatAttachmentDraftStatus.ready,
          attachment: attachment,
        ),
      );
    } on ChatAttachmentException catch (error) {
      _replace(
        id,
        draft.copyWith(
          status: ChatAttachmentDraftStatus.failed,
          errorMessage: error.userMessage,
        ),
      );
    } catch (_) {
      _replace(
        id,
        draft.copyWith(
          status: ChatAttachmentDraftStatus.failed,
          errorMessage: 'This attachment could not be prepared.',
        ),
      );
    }
  }

  Future<void> remove(String id) async {
    ChatAttachmentDraft? target;
    for (final draft in state) {
      if (draft.id == id) {
        target = draft;
        break;
      }
    }
    if (target == null) return;
    emit(state.where((draft) => draft.id != id).toList(growable: false));
    final attachment = target.attachment;
    if (attachment != null) await _preparer.deletePrepared(attachment);
  }

  List<PreparedChatAttachment> consumeReadyAttachments() {
    final ready = readyAttachments;
    emit(
      state
          .where((draft) => draft.status != ChatAttachmentDraftStatus.ready)
          .toList(growable: false),
    );
    return ready;
  }

  Future<void> clear() async {
    final prepared = state
        .map((draft) => draft.attachment)
        .whereType<PreparedChatAttachment>()
        .toList(growable: false);
    emit(const []);
    for (final attachment in prepared) {
      await _preparer.deletePrepared(attachment);
    }
  }

  void _replace(String id, ChatAttachmentDraft replacement) {
    if (!state.any((draft) => draft.id == id)) {
      final attachment = replacement.attachment;
      if (attachment != null) {
        unawaited(_preparer.deletePrepared(attachment));
      }
      return;
    }
    emit([for (final draft in state) draft.id == id ? replacement : draft]);
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty || segments.last.isEmpty
        ? 'attachment'
        : segments.last;
  }
}
