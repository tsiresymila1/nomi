import 'package:gena/features/downloads/data/models/model_info.dart';
import 'local_model_runtime.dart';

/// Builds the unsupported-platform local model runtime (e.g. web).
LocalModelRuntime createLocalModelRuntime() => UnsupportedLocalModelRuntime();

/// Rejects all local model preparation. Used on platforms without native
/// llamadart support, such as web.
class UnsupportedLocalModelRuntime implements LocalModelRuntime {
  @override
  Future<PreparedLocalModel> prepare(ModelInfo model) {
    throw const LocalModelRuntimeException(
      'Local models are unavailable on this platform. Remote models remain '
      'available.',
    );
  }

  @override
  Future<int> countTokens(String text) async => fallbackTokenEstimate(text);

  @override
  void cancelActiveGeneration() {}

  @override
  Future<void> reset() async {}
}
