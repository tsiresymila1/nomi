import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

/// In-memory fake backend that keeps per-collection state so we can assert that
/// each workspace is isolated and rebuilding one does not affect another.
class FakeWorkspaceRagBackend implements WorkspaceRagBackend {
  final Map<String, List<int>> sourcesByCollection = <String, List<int>>{};
  final Map<String, int> rebuildCounts = <String, int>{};
  final Map<String, List<WorkspaceRagResult>> hitsByCollection =
      <String, List<WorkspaceRagResult>>{};
  var _nextSourceId = 1;
  var ensureReadyCount = 0;

  @override
  Future<void> ensureReady() async {
    ensureReadyCount++;
  }

  @override
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  ) async {
    final collection = workspaceRagCollectionId(workspaceId);
    final sourceId = _nextSourceId++;
    sourcesByCollection.putIfAbsent(collection, () => <int>[]).add(sourceId);
    return WorkspaceRagIngestResult(sourceId: sourceId, chunkCount: 2);
  }

  @override
  Future<void> removeDocument(String workspaceId, int sourceId) async {
    final collection = workspaceRagCollectionId(workspaceId);
    sourcesByCollection[collection]?.remove(sourceId);
  }

  @override
  Future<void> rebuildWorkspace(String workspaceId) async {
    final collection = workspaceRagCollectionId(workspaceId);
    rebuildCounts[collection] = (rebuildCounts[collection] ?? 0) + 1;
  }

  @override
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  }) async {
    final collection = workspaceRagCollectionId(workspaceId);
    return hitsByCollection[collection] ?? const [];
  }
}

void main() {
  final supported = AppCapabilities.forPlatform(AppPlatform.android);

  WorkspaceRagVectorStore buildStore(FakeWorkspaceRagBackend backend) =>
      WorkspaceRagVectorStore(capabilities: supported, backend: backend);

  test('addDocument is scoped to the workspace collection and returns the '
      'engine source id', () async {
    final backend = FakeWorkspaceRagBackend();
    final store = buildStore(backend);

    final result = await store.addDocument(
      workspaceId: '1',
      documentId: 100,
      sourceType: 'text',
      sourcePath: '/a.txt',
      name: 'a.txt',
      content: 'hello',
    );

    expect(result.sourceId, 1);
    expect(result.chunkCount, 2);
    expect(backend.sourcesByCollection['workspace_1'], [1]);
    expect(backend.sourcesByCollection.containsKey('workspace_2'), isFalse);
  });

  test('removeDocument only affects its own workspace collection', () async {
    final backend = FakeWorkspaceRagBackend();
    final store = buildStore(backend);

    await store.addDocument(
      workspaceId: '1',
      documentId: 1,
      sourceType: 'text',
      sourcePath: '/a',
      name: 'a',
      content: 'a',
    );
    await store.addDocument(
      workspaceId: '2',
      documentId: 2,
      sourceType: 'text',
      sourcePath: '/b',
      name: 'b',
      content: 'b',
    );

    await store.removeDocument(workspaceId: '1', sourceId: 1);

    expect(backend.sourcesByCollection['workspace_1'], isEmpty);
    expect(backend.sourcesByCollection['workspace_2'], [2]);
  });

  test('rebuilding one workspace does not clear another workspace', () async {
    final backend = FakeWorkspaceRagBackend();
    final store = buildStore(backend);

    await store.addDocument(
      workspaceId: '1',
      documentId: 1,
      sourceType: 'text',
      sourcePath: '/a',
      name: 'a',
      content: 'a',
    );
    await store.addDocument(
      workspaceId: '2',
      documentId: 2,
      sourceType: 'text',
      sourcePath: '/b',
      name: 'b',
      content: 'b',
    );

    await store.rebuildWorkspace('1');

    // workspace_1 was rebuilt; workspace_2 sources remain untouched.
    expect(backend.rebuildCounts['workspace_1'], 1);
    expect(backend.rebuildCounts.containsKey('workspace_2'), isFalse);
    expect(backend.sourcesByCollection['workspace_2'], [2]);
  });

  test(
    'search only returns hits from the active workspace collection',
    () async {
      final backend = FakeWorkspaceRagBackend();
      backend.hitsByCollection['workspace_1'] = const [
        WorkspaceRagResult(
          id: 'wsdoc_1_chunk_0',
          similarity: 0.8,
          content: 'ws1 content',
          metadata: '{}',
        ),
      ];
      backend.hitsByCollection['workspace_2'] = const [
        WorkspaceRagResult(
          id: 'wsdoc_2_chunk_0',
          similarity: 0.8,
          content: 'ws2 content',
          metadata: '{}',
        ),
      ];
      final store = buildStore(backend);

      final results = await store.searchWorkspace(workspaceId: '1', query: 'q');

      expect(results.single.content, 'ws1 content');
    },
  );

  test(
    'search returns empty for blank queries without hitting the backend',
    () async {
      final backend = FakeWorkspaceRagBackend();
      final store = buildStore(backend);

      final results = await store.searchWorkspace(
        workspaceId: '1',
        query: '   ',
      );

      expect(results, isEmpty);
      expect(backend.ensureReadyCount, 0);
    },
  );
}
