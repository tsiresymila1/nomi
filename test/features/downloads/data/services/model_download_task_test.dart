import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/services/model_download_task.dart';

void main() {
  group('buildModelDownloadTask', () {
    test('builds a resumable persistent model download task', () {
      final task = buildModelDownloadTask(
        modelKey: 'model_42',
        modelName: 'Gemma 4',
        sourceUrl: 'https://example.com/models/gemma.task',
        fileName: 'gemma.task',
      );

      expect(task.taskId, modelDownloadTaskId('model_42'));
      expect(task.group, modelDownloadsGroup);
      expect(task.directory, modelDownloadsDirectory);
      expect(task.baseDirectory, BaseDirectory.applicationSupport);
      expect(task.updates, Updates.statusAndProgress);
      expect(task.allowPause, isTrue);
      expect(task.retries, 3);
      expect(task.metaData, 'model_42');
      expect(task.displayName, 'Gemma 4');
    });

    test('adds a Hugging Face bearer token when provided', () {
      final task = buildModelDownloadTask(
        modelKey: 'model_42',
        modelName: 'Gemma 4',
        sourceUrl: 'https://huggingface.co/model.task',
        fileName: 'model.task',
        huggingFaceToken: 'secret-token',
      );

      expect(
        task.headers[HttpHeaders.authorizationHeader],
        'Bearer secret-token',
      );
    });

    test('uses a deterministic safe task id', () {
      final first = modelDownloadTaskId('runtime_Gemma 4/remote:model');
      final second = modelDownloadTaskId('runtime_Gemma 4/remote:model');

      expect(first, second);
      expect(first, startsWith('model_download_'));
      expect(first, matches(RegExp(r'^[a-zA-Z0-9_-]+$')));
    });
  });

  group('model download snapshots', () {
    test('maps task records into app-owned snapshots', () {
      final task = buildModelDownloadTask(
        modelKey: 'model_42',
        modelName: 'Gemma 4',
        sourceUrl: 'https://example.com/gemma.task',
        fileName: 'gemma.task',
      );

      final snapshot = modelDownloadSnapshotFromRecord(
        TaskRecord(task, TaskStatus.running, 0.45, 1000),
      );

      expect(snapshot.id, task.taskId);
      expect(snapshot.modelKey, 'model_42');
      expect(snapshot.progress, 0.45);
      expect(snapshot.status, ModelDownloadStatus.running);
      expect(snapshot.isTerminal, isFalse);
    });

    test('maps canceled records to terminal canceled snapshots', () {
      final task = buildModelDownloadTask(
        modelKey: 'model_42',
        modelName: 'Gemma 4',
        sourceUrl: 'https://example.com/gemma.task',
        fileName: 'gemma.task',
      );

      final snapshot = modelDownloadSnapshotFromRecord(
        TaskRecord(task, TaskStatus.canceled, progressCanceled, 1000),
      );

      expect(snapshot.progress, 0);
      expect(snapshot.status, ModelDownloadStatus.cancelled);
      expect(snapshot.isTerminal, isTrue);
    });
  });
}
