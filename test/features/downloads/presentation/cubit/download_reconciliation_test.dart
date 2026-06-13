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
      expect(
        reconciled.activeInstall?.ownership,
        ActiveModelInstallOwnership.restored,
      );
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
          ownership: ActiveModelInstallOwnership.restored,
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

    test('old terminal snapshot does not settle a newer active attempt', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.2},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
          ownership: ActiveModelInstallOwnership.restored,
        ),
      );
      final oldTerminal = ModelDownloadSnapshot(
        id: 'attempt_1',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0,
        status: ModelDownloadStatus.failed,
        message: 'Old attempt failed',
        error: 'Old failure',
      );
      final newerActive = ModelDownloadSnapshot(
        id: 'attempt_2',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0.65,
        status: ModelDownloadStatus.running,
        message: 'Gemma 4 65%',
      );

      final reconciled = reconcileBackgroundDownloads(state, [
        oldTerminal,
        newerActive,
      ]);

      expect(reconciled.activeInstall, isNotNull);
      expect(reconciled.progressByKey['model_42'], 0.65);
      expect(reconciled.errorMessage, isNull);
    });

    test('latest active snapshot supplies current attempt progress', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.2},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
          ownership: ActiveModelInstallOwnership.restored,
        ),
      );
      final oldActive = ModelDownloadSnapshot(
        id: 'attempt_1',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0.2,
        status: ModelDownloadStatus.running,
        message: 'Gemma 4 20%',
      );
      final newerActive = ModelDownloadSnapshot(
        id: 'attempt_2',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0.65,
        status: ModelDownloadStatus.running,
        message: 'Gemma 4 65%',
      );

      final reconciled = reconcileBackgroundDownloads(state, [
        oldActive,
        newerActive,
      ]);

      expect(reconciled.progressByKey['model_42'], 0.65);
    });

    test('terminal snapshot settles only after no active attempt remains', () {
      final state = DownloadsState(
        models: [_model(id: 42, name: 'Gemma 4')],
        progressByKey: const {'model_42': 0.65},
        activeInstall: const ActiveModelInstall(
          key: 'model_42',
          label: 'Gemma 4',
          ownership: ActiveModelInstallOwnership.restored,
        ),
      );
      final newerTerminal = ModelDownloadSnapshot(
        id: 'attempt_2',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 1,
        status: ModelDownloadStatus.complete,
        message: 'Gemma 4 downloaded',
      );
      final oldTerminal = ModelDownloadSnapshot(
        id: 'attempt_1',
        modelKey: 'model_42',
        modelLabel: 'Gemma 4',
        progress: 0,
        status: ModelDownloadStatus.failed,
        message: 'Old attempt failed',
        error: 'Old failure',
      );

      final reconciled = reconcileBackgroundDownloads(state, [
        oldTerminal,
        newerTerminal,
      ]);

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
          ownership: ActiveModelInstallOwnership.restored,
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
          ownership: ActiveModelInstallOwnership.restored,
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
          ownership: ActiveModelInstallOwnership.restored,
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

    for (final status in [
      ModelDownloadStatus.complete,
      ModelDownloadStatus.failed,
      ModelDownloadStatus.cancelled,
    ]) {
      test('does not settle a terminal live download with status $status', () {
        final state = DownloadsState(
          models: [_model(id: 42, name: 'Gemma 4')],
          progressByKey: const {'model_42': 0.9},
          activeInstall: const ActiveModelInstall(
            key: 'model_42',
            label: 'Gemma 4',
            ownership: ActiveModelInstallOwnership.live,
          ),
        );
        final snapshot = ModelDownloadSnapshot(
          id: 'download_42',
          modelKey: 'model_42',
          modelLabel: 'Gemma 4',
          progress: status == ModelDownloadStatus.complete ? 1 : 0,
          status: status,
          message: 'terminal snapshot',
          error: status == ModelDownloadStatus.failed ? 'failed' : null,
        );

        final reconciled = reconcileBackgroundDownloads(state, [snapshot]);

        expect(reconciled, same(state));
        expect(
          reconciled.activeInstall?.ownership,
          ActiveModelInstallOwnership.live,
        );
      });
    }
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
