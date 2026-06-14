import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/unsupported_workspace_rag_backend.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';

/// A fake backend that mimics the native adapter's collection scoping and
/// metadata/result translation without depending on `mobile_rag_engine`.
class FakeRagEngineHit {
  FakeRagEngineHit({
    required this.sourceId,
    required this.chunkIndex,
    required this.content,
    required this.score,
    required this.metadata,
  });

  final int sourceId;
  final int chunkIndex;
  final String content;
  final double score;
  final String metadata;
}

class FakeWorkspaceRagBackend implements WorkspaceRagBackend {
  final List<String> ensureReadyCalls = <String>[];
  final List<String> usedCollections = <String>[];
  final Map<String, List<String>> ingestedMetadata = <String, List<String>>{};
  final Map<String, List<FakeRagEngineHit>> hitsByCollection =
      <String, List<FakeRagEngineHit>>{};

  var _nextSourceId = 1;

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls.add('ready');
  }

  @override
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  ) async {
    await ensureReady();
    final collection = workspaceRagCollectionId(workspaceId);
    usedCollections.add(collection);
    final metadata = jsonEncode({
      'workspace_id': workspaceId,
      'document_id': document.documentId,
      'source_type': document.sourceType,
      'source_path': document.sourcePath,
      'name': document.name,
    });
    ingestedMetadata.putIfAbsent(collection, () => <String>[]).add(metadata);
    final sourceId = _nextSourceId++;
    return WorkspaceRagIngestResult(sourceId: sourceId, chunkCount: 3);
  }

  @override
  Future<void> removeDocument(String workspaceId, int sourceId) async {
    usedCollections.add(workspaceRagCollectionId(workspaceId));
  }

  @override
  Future<void> rebuildWorkspace(String workspaceId) async {
    usedCollections.add(workspaceRagCollectionId(workspaceId));
  }

  @override
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  }) async {
    final collection = workspaceRagCollectionId(workspaceId);
    usedCollections.add(collection);
    final hits = hitsByCollection[collection] ?? const [];
    return hits
        .where((hit) => hit.score >= threshold)
        .take(topK)
        .map(
          (hit) => WorkspaceRagResult(
            id: 'wsdoc_${hit.sourceId}_chunk_${hit.chunkIndex}',
            similarity: hit.score,
            content: hit.content,
            metadata: hit.metadata,
          ),
        )
        .toList(growable: false);
  }
}

void main() {
  group('workspaceRagCollectionId', () {
    test('produces workspace_<id> collection name', () {
      expect(workspaceRagCollectionId('42'), 'workspace_42');
      expect(workspaceRagCollectionId('abc'), 'workspace_abc');
    });
  });

  group('FakeWorkspaceRagBackend contract', () {
    test('ingest scopes the document to the workspace collection and maps '
        'metadata', () async {
      final backend = FakeWorkspaceRagBackend();
      final result = await backend.addDocument(
        '7',
        const WorkspaceRagDocument(
          documentId: 11,
          name: 'manual.pdf',
          sourceType: 'pdf',
          sourcePath: '/docs/manual.pdf',
          content: 'hello world',
        ),
      );

      expect(result.sourceId, 1);
      expect(result.chunkCount, 3);
      expect(backend.usedCollections, contains('workspace_7'));

      final metadata =
          jsonDecode(backend.ingestedMetadata['workspace_7']!.single)
              as Map<String, dynamic>;
      expect(metadata['workspace_id'], '7');
      expect(metadata['document_id'], 11);
      expect(metadata['source_type'], 'pdf');
      expect(metadata['source_path'], '/docs/manual.pdf');
      expect(metadata['name'], 'manual.pdf');
    });

    test('search translates engine hits into provider-neutral results and '
        'filters below threshold', () async {
      final backend = FakeWorkspaceRagBackend();
      backend.hitsByCollection['workspace_3'] = [
        FakeRagEngineHit(
          sourceId: 5,
          chunkIndex: 0,
          content: 'relevant chunk',
          score: 0.9,
          metadata: '{"name":"a"}',
        ),
        FakeRagEngineHit(
          sourceId: 6,
          chunkIndex: 2,
          content: 'weak chunk',
          score: 0.05,
          metadata: '{"name":"b"}',
        ),
      ];

      final results = await backend.search(
        '3',
        'query',
        topK: 4,
        threshold: 0.15,
      );

      expect(results, hasLength(1));
      expect(results.single, isA<WorkspaceRagResult>());
      expect(results.single.id, 'wsdoc_5_chunk_0');
      expect(results.single.content, 'relevant chunk');
      expect(results.single.similarity, 0.9);
      expect(results.single.metadata, '{"name":"a"}');
    });

    test('search only queries the active workspace collection', () async {
      final backend = FakeWorkspaceRagBackend();
      backend.hitsByCollection['workspace_1'] = [
        FakeRagEngineHit(
          sourceId: 1,
          chunkIndex: 0,
          content: 'ws1',
          score: 0.9,
          metadata: '{}',
        ),
      ];
      backend.hitsByCollection['workspace_2'] = [
        FakeRagEngineHit(
          sourceId: 2,
          chunkIndex: 0,
          content: 'ws2',
          score: 0.9,
          metadata: '{}',
        ),
      ];

      final results = await backend.search('1', 'q', topK: 4, threshold: 0.0);

      expect(results.single.content, 'ws1');
      expect(backend.usedCollections, contains('workspace_1'));
      expect(backend.usedCollections, isNot(contains('workspace_2')));
    });
  });

  group('UnsupportedWorkspaceRagBackend', () {
    const backend = UnsupportedWorkspaceRagBackend();

    test('ensureReady throws UnsupportedPlatformException', () {
      expect(
        () => backend.ensureReady(),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('search throws UnsupportedPlatformException', () {
      expect(
        () => backend.search('1', 'q', topK: 4, threshold: 0.15),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('addDocument throws UnsupportedPlatformException', () {
      expect(
        () => backend.addDocument(
          '1',
          const WorkspaceRagDocument(
            documentId: 1,
            name: 'n',
            sourceType: 'text',
            sourcePath: '/p',
            content: 'c',
          ),
        ),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });
  });
}
