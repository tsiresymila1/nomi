import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_bootstrap.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

void main() {
  final unsupported = AppCapabilities.forPlatform(AppPlatform.web);

  group('WorkspaceRagActions unsupported platform policy', () {
    late WorkspaceRagActions actions;

    setUp(() {
      actions = WorkspaceRagActions(
        database: _UnexpectedDatabase(),
        parser: _UnexpectedParser(),
        vectorStore: _UnexpectedVectorStore(),
        ingestionQueue: _UnexpectedQueue(),
        ingestionBootstrap: _UnexpectedBootstrap(),
        capabilities: unsupported,
      );
    });

    test(
      'RAG tool returns unsupported_platform before initialization',
      () async {
        final result = await actions.runRagTool(
          workspaceId: '1',
          query: 'hello',
        );

        expect(result['status'], 'error');
        expect(result['error'], 'unsupported_platform');
        expect(result['message'], unsupported.workspaceRagUnavailableMessage);
      },
    );

    test('automatic augmented prompt skips RAG and preserves prompt', () async {
      const prompt = 'Use the persisted workspace knowledge';

      final result = await actions.buildAugmentedPrompt(
        workspaceId: '1',
        userPrompt: prompt,
      );

      expect(result, prompt);
    });

    test('import fails before parsing or ingestion', () {
      expect(
        () => actions.importDocument(workspaceId: '1', rawPath: '/tmp/a.txt'),
        throwsA(_isUnsupportedPlatformError),
      );
    });

    test('retry fails before database access or ingestion', () {
      expect(
        () => actions.retryDocumentIngestion(1),
        throwsA(_isUnsupportedPlatformError),
      );
    });

    test('rebuild fails before database access or vector initialization', () {
      expect(
        actions.rebuildAllDocumentsIndex,
        throwsA(_isUnsupportedPlatformError),
      );
    });
  });

  group('WorkspaceRagIngestionQueue unsupported platform policy', () {
    late WorkspaceRagIngestionQueue queue;

    setUp(() {
      queue = WorkspaceRagIngestionQueue(
        database: _UnexpectedDatabase(),
        parser: _UnexpectedParser(),
        vectorStore: _UnexpectedVectorStore(),
        capabilities: unsupported,
      );
    });

    test('enqueue fails before ingestion starts', () {
      expect(() => queue.enqueue(1), throwsA(_isUnsupportedPlatformError));
    });

    test('resume fails before database access', () {
      expect(queue.resumePending, throwsA(_isUnsupportedPlatformError));
    });
  });

  group('lowest-level RAG services unsupported platform policy', () {
    test('vector store fails before initialization or search', () {
      final vectorStore = WorkspaceRagVectorStore(capabilities: unsupported);

      expect(vectorStore.ensureReady, throwsA(_isUnsupportedPlatformError));
      expect(
        () => vectorStore.searchWorkspace(workspaceId: '1', query: 'hello'),
        throwsA(_isUnsupportedPlatformError),
      );
    });

    test('embedder installer fails before status or installation work', () {
      final installer = WorkspaceEmbedderInstaller(capabilities: unsupported);
      var statusCalled = false;

      expect(
        () => installer.ensureInstalled(
          onStatus: ({required message, modelProgress, tokenizerProgress}) {
            statusCalled = true;
          },
        ),
        throwsA(_isUnsupportedPlatformError),
      );
      expect(statusCalled, isFalse);
    });
  });
}

final Matcher _isUnsupportedPlatformError = isA<UnsupportedPlatformException>()
    .having((error) => error.code, 'code', 'unsupported_platform');

class _UnexpectedDatabase extends Fake implements GenaDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Database must not be accessed: $invocation');
  }
}

class _UnexpectedParser extends Fake implements WorkspaceDocumentParser {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Parser must not be accessed: $invocation');
  }
}

class _UnexpectedVectorStore extends Fake implements WorkspaceRagVectorStore {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Vector store must not be accessed: $invocation');
  }
}

class _UnexpectedQueue extends Fake implements WorkspaceRagIngestionQueue {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Queue must not be accessed: $invocation');
  }
}

class _UnexpectedBootstrap extends Fake
    implements WorkspaceRagIngestionBootstrap {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Bootstrap must not be accessed: $invocation');
  }
}
