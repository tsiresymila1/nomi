import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';

/// Builds the unsupported-platform RAG backend (e.g. web).
WorkspaceRagBackend createWorkspaceRagBackend() =>
    const UnsupportedWorkspaceRagBackend();

/// Rejects all workspace RAG operations on platforms without local RAG
/// support, such as web. Deliberately does not import `mobile_rag_engine`.
class UnsupportedWorkspaceRagBackend implements WorkspaceRagBackend {
  const UnsupportedWorkspaceRagBackend();

  static const _message =
      'Workspace RAG is unavailable on this platform. Remote models remain '
      'available.';

  @override
  Future<void> ensureReady() async {
    throw const UnsupportedPlatformException(_message);
  }

  @override
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  ) async {
    throw const UnsupportedPlatformException(_message);
  }

  @override
  Future<void> removeDocument(String workspaceId, int sourceId) async {
    throw const UnsupportedPlatformException(_message);
  }

  @override
  Future<void> rebuildWorkspace(String workspaceId) async {
    throw const UnsupportedPlatformException(_message);
  }

  @override
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  }) async {
    throw const UnsupportedPlatformException(_message);
  }
}
