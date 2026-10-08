import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

import 'local_model_runtime.dart';

/// Keeps the resident llamadart runtime inside the shared local-AI memory
/// budget. The lease is retained while the model is loaded and released only
/// after reset or coordinator-driven eviction.
class CoordinatedLocalModelRuntime implements LocalModelRuntime {
  CoordinatedLocalModelRuntime({
    required LocalModelRuntime delegate,
    required LocalAiRuntimeCoordinator coordinator,
  }) : _delegate = delegate,
       _coordinator = coordinator;

  final LocalModelRuntime _delegate;
  final LocalAiRuntimeCoordinator _coordinator;

  LocalAiRuntimeLease? _lease;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<PreparedLocalModel> prepare(ModelInfo model) {
    return _serialize(() async {
      var lease = _lease;
      if (lease == null || !lease.isActive) {
        lease = await _coordinator.acquire(
          LocalAiWorkload.chat,
          onEvict: _evict,
        );
        _lease = lease;
      }

      try {
        return await _delegate.prepare(model);
      } catch (_) {
        if (identical(_lease, lease)) _lease = null;
        await lease.release();
        rethrow;
      }
    });
  }

  Future<void> _evict() async {
    _delegate.cancelActiveGeneration();
    await _delegate.reset();
    _lease = null;
  }

  @override
  Future<int> countTokens(String text) => _delegate.countTokens(text);

  @override
  void cancelActiveGeneration() => _delegate.cancelActiveGeneration();

  @override
  Future<void> reset() {
    return _serialize(() async {
      final lease = _lease;
      try {
        await _delegate.reset();
      } finally {
        if (identical(_lease, lease)) _lease = null;
        await lease?.release();
      }
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then<T>((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
