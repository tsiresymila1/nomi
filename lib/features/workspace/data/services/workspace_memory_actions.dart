import 'package:gena/features/workspace/data/workspace_memory_repository.dart';

/// Bridges the chat runtime to [WorkspaceMemoryRepository] for the
/// `remember`/`forget` tools and for composing the auto-injected memory block.
///
/// Memory content is sensitive and is never logged here.
class WorkspaceMemoryActions {
  WorkspaceMemoryActions({required WorkspaceMemoryRepository repository})
    : _repository = repository;

  /// Default upper bound on the total characters injected into the system
  /// instruction. Newest memories are kept; older ones are dropped from the
  /// block (never deleted from storage) when the budget is exceeded.
  static const int defaultInjectionCharBudget = 2000;

  static const String memoryBlockHeader = 'Remembered facts about the user:';

  final WorkspaceMemoryRepository _repository;

  /// Stores a fact for [workspaceId]. Local write, no approval.
  Future<Map<String, dynamic>> runRememberTool({
    required String workspaceId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_content',
        'message': 'Nothing to remember: content is empty.',
      };
    }

    final result = await _repository.addMemory(workspaceId, trimmed);
    switch (result.status) {
      case WorkspaceMemoryAddStatus.invalidWorkspace:
        return <String, dynamic>{
          'status': 'error',
          'error': 'invalid_workspace',
          'message': 'No active workspace to store memory.',
        };
      case WorkspaceMemoryAddStatus.empty:
        return <String, dynamic>{
          'status': 'error',
          'error': 'invalid_content',
          'message': 'Nothing to remember: content is empty.',
        };
      case WorkspaceMemoryAddStatus.duplicate:
        return <String, dynamic>{
          'status': 'success',
          'stored': false,
          'duplicate': true,
          'count': result.totalCount,
          'message': 'Already remembered.',
        };
      case WorkspaceMemoryAddStatus.stored:
        return <String, dynamic>{
          'status': 'success',
          'stored': true,
          'count': result.totalCount,
          'message': 'Remembered.',
        };
      case WorkspaceMemoryAddStatus.storedWithTrim:
        return <String, dynamic>{
          'status': 'success',
          'stored': true,
          'count': result.totalCount,
          'trimmed': result.trimmedCount,
          'message':
              'Remembered. Memory was full, so '
              '${result.trimmedCount} oldest fact(s) were dropped.',
        };
    }
  }

  /// Removes a matching fact for [workspaceId] by content (or by [id]).
  Future<Map<String, dynamic>> runForgetTool({
    required String workspaceId,
    String? content,
    int? id,
  }) async {
    if (id != null) {
      final removed = await _repository.deleteMemory(id);
      return <String, dynamic>{
        'status': 'success',
        'removed': removed,
        'message': removed > 0 ? 'Forgotten.' : 'No matching memory found.',
      };
    }

    final trimmed = content?.trim() ?? '';
    if (trimmed.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_content',
        'message': 'Provide the content (or id) of the fact to forget.',
      };
    }

    final removed = await _repository.deleteByContent(workspaceId, trimmed);
    return <String, dynamic>{
      'status': 'success',
      'removed': removed,
      'message': removed > 0 ? 'Forgotten.' : 'No matching memory found.',
    };
  }

  /// Builds the bounded "Remembered facts" block for [workspaceId], newest
  /// first. Returns an empty string when there are no memories. The total
  /// length is capped at [charBudget].
  Future<String> buildMemoryBlock({
    required String workspaceId,
    int charBudget = defaultInjectionCharBudget,
  }) async {
    final memories = await _repository.listMemories(workspaceId);
    return composeMemoryBlock(
      contents: memories.map((m) => m.content).toList(growable: false),
      charBudget: charBudget,
    );
  }

  /// Pure composition of the memory block from newest-first [contents].
  ///
  /// Bullets are added until adding the next one would exceed [charBudget].
  static String composeMemoryBlock({
    required List<String> contents,
    int charBudget = defaultInjectionCharBudget,
  }) {
    final cleaned = contents
        .map((c) => c.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return '';

    final buffer = StringBuffer(memoryBlockHeader);
    var any = false;
    for (final content in cleaned) {
      final line = '\n- $content';
      if (buffer.length + line.length > charBudget) break;
      buffer.write(line);
      any = true;
    }
    if (!any) return '';
    return buffer.toString();
  }
}
