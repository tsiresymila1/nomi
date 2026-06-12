import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/services/model_download_task.dart';
import 'package:gena/features/downloads/presentation/cubit/download_reconciliation.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';

void main() {
  group('reconcileBackgroundDownloads', () {
    test('restores a catalog-backed active download after restart', () {
      final state = DownloadsState(models: [_model(id: 42, name: 'Gemma 4')]);
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Persisted label',
        progress: 0.45,
        status: ModelDownloadStatus.running,
        message: 'Gemma 4 45%',
      );

      final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

      expect(reconciled.activeInstall?.key, 'model_42');
      expect(reconciled.activeInstall?.label, 'Gemma 4');
      expect(reconciled.progressByKey['model_42'], 0.45);
    });

    test('ignores a carried download that cannot map to the catalog', () {
      final state = DownloadsState(models: [_model(id: 42, name: 'Gemma 4')]);
      final snapshot = ModelDownloadSnapshot(
        id: 'download_unknown',
        modelKey: 'model_999',
        modelLabel: 'Unknown',
        progress: 0.45,
        status: ModelDownloadStatus.running,
        message: 'Unknown 45%',
      );

      final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

      expect(reconciled.activeInstall, isNull);
      expect(reconciled.progressByKey, isEmpty);
    });

    test('restores a previously unknown download once the catalog arrives', () {
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Persisted label',
        progress: 0.45,
        status: ModelDownloadStatus.running,
        message: 'Gemma 4 45%',
      );
      final beforeCatalog = reconcileBackgroundDownloads(
        const DownloadsState(models: []),
        [snapshot],
      );

      final afterCatalog = reconcileBackgroundDownloads(
        beforeCatalog.copyWith(models: [_model(id: 42, name: 'Gemma 4')]),
        [snapshot],
      );

      expect(afterCatalog.activeInstall?.key, 'model_42');
      expect(afterCatalog.progressByKey['model_42'], 0.45);
    });

    test('settles a carried active download when it completes', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.9},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
        ),
        errorMessage: 'old error',
      );
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 1,
        status: ModelDownloadStatus.complete,
        message: 'Gemma 4 downloaded',
      );

      final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

      expect(reconciled.activeInstall, isNull);
      expect(reconciled.progressByKey, isEmpty);
      expect(reconciled.errorMessage, isNull);
    });

    test('settles a carried active download when it fails', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.45},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
        ),
      );
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0,
        status: ModelDownloadStatus.failed,
        message: 'Gemma 4 failed',
        error: 'Network unavailable',
      );

      final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

      expect(reconciled.activeInstall, isNull);
      expect(reconciled.progressByKey, isEmpty);
      expect(reconciled.errorMessage, 'Network unavailable');
    });

    test('settles a cancelled carried active download without an error', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.45},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
        ),
        errorMessage: 'old error',
      );
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0,
        status: ModelDownloadStatus.cancelled,
        message: 'Gemma 4 cancelled',
      );

      final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

      expect(reconciled.activeInstall, isNull);
      expect(reconciled.progressByKey, isEmpty);
      expect(reconciled.errorMessage, isNull);
    });

    test('does not repeatedly emit a stale carried failure', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.45},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
        ),
      );
      final snapshot = ModelDownloadSnapshot(
        id: 'download_42',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0,
        status: ModelDownloadStatus.failed,
        message: 'Gemma 4 failed',
      );
      final settled = reconcileBackgroundDownloads(state, [snapshot]);

      final reconciledAgain = reconcileBackgroundDownloads(settled, [snapshot]);

      expect(reconciledAgain, same(settled));
    });
  });
}

ModelInfo _model({required int id, required String name}) {
  return ModelInfo(
    id: id,
    name: name,
    description: '',
    provider: 'local',
    modelType: 'gemmaIt',
    supportImage: false,
    supportAudio: false,
    supportsFunctionCalls: false,
    isThinking: false,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 2048,
    tokenBuffer: 256,
    randomSeed: 1,
    preferredBackend: 'gpu',
    sourceType: 'network',
    source: 'https://example.com/model.task',
  );
}
