import 'package:genkit/genkit.dart' hide ModelInfo;

import 'package:gena/features/downloads/data/local_model_files.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

/// Provider-neutral local model runtime contract.
///
/// Implementations own loading a local model file, exposing a Genkit instance
/// plus model reference for generation, forwarding cancellation, and disposing
/// the underlying runtime when the selected model changes.
abstract interface class LocalModelRuntime {
  /// Loads (or reuses) the runtime for [model] and returns a prepared handle.
  Future<PreparedLocalModel> prepare(ModelInfo model);

  /// Estimates the token count of [text].
  Future<int> countTokens(String text);

  /// Cancels any in-flight generation on the active runtime.
  void cancelActiveGeneration();

  /// Disposes the active runtime, if any.
  Future<void> reset();
}

/// A loaded local model exposed to the generation path.
class PreparedLocalModel {
  const PreparedLocalModel({
    required this.ai,
    required this.modelRef,
    required this.modelId,
  });

  /// Genkit instance with the local plugin registered.
  final Genkit ai;

  /// Typed Genkit reference for the prepared model.
  final ModelRef<dynamic> modelRef;

  /// Stable app-owned identity for the prepared model file.
  final String modelId;
}

/// Raised when a local model cannot be prepared.
class LocalModelRuntimeException implements Exception {
  const LocalModelRuntimeException(this.message);

  final String message;

  @override
  String toString() => 'LocalModelRuntimeException: $message';
}

/// Conservative fallback token estimate (~4 characters per token), used when a
/// runtime cannot tokenize text natively.
int fallbackTokenEstimate(String text) {
  if (text.isEmpty) return 0;
  return (text.runes.length / 4).ceil();
}

const _supportedLocalModelExtensions = <String>{'.gguf', '.litertlm'};

/// Returns the lowercase file extension of a local model [source], or null.
String? localModelRuntimeExtension(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  final path = uri != null && uri.hasScheme ? uri.path : trimmed;
  final fileName = path.split(RegExp(r'[/\\]')).last.toLowerCase();
  final index = fileName.lastIndexOf('.');
  if (index < 0) return null;
  return fileName.substring(index);
}

/// Resolves a stored projector source to a canonical local file path.
///
/// Returns null when the projector is absent, blank, or still a remote URL
/// (i.e. the projector has not been downloaded yet). Once the downloader has
/// fetched the projector it persists the local path, which resolves here.
String? resolveLocalMmprojPath(String? mmprojSource) {
  final trimmed = mmprojSource?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  return canonicalLocalModelPath(trimmed);
}

/// Whether [source] points at a llamadart-compatible local model file.
bool isLocalModelRuntimeSource(String source) {
  final extension = localModelRuntimeExtension(source);
  return extension != null &&
      _supportedLocalModelExtensions.contains(extension);
}

/// Request describing a runtime load. Settings that affect native loading
/// (model file and context window) live here; sampling settings are request
/// time and stay on the generation config.
class LocalRuntimeRequest {
  const LocalRuntimeRequest({
    required this.modelInfo,
    required this.contextSize,
    required this.constrainedOutput,
    this.mmprojPath,
  });

  final ModelInfo modelInfo;
  final int contextSize;
  final bool constrainedOutput;

  /// Resolved local path to the multimodal projector (`mmproj-*.gguf`), or null
  /// when the model is text-only or the projector is not yet downloaded.
  final String? mmprojPath;
}

/// A loaded runtime returned by a [LocalRuntimeLoader].
class LoadedLocalRuntime {
  const LoadedLocalRuntime({
    required this.ai,
    required this.modelRef,
    required this.modelId,
    required this.cancel,
    required this.dispose,
  });

  final Genkit ai;
  final ModelRef<dynamic> modelRef;
  final String modelId;
  final void Function() cancel;
  final Future<void> Function() dispose;
}

/// Loads the underlying native runtime. Injected so the caching state machine
/// is testable without native libraries.
abstract interface class LocalRuntimeLoader {
  Future<LoadedLocalRuntime> load(LocalRuntimeRequest request);
}

/// Caches one prepared local runtime, disposing the previous one before
/// switching to a different model file or context window.
class CachingLocalModelRuntime implements LocalModelRuntime {
  CachingLocalModelRuntime(this._loader);

  final LocalRuntimeLoader _loader;

  LoadedLocalRuntime? _current;
  PreparedLocalModel? _prepared;
  String? _cacheKey;
  ({Object error, StackTrace stackTrace})? _disposeFailure;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<PreparedLocalModel> prepare(ModelInfo model) {
    return _serialize(() => _prepare(model));
  }

  Future<PreparedLocalModel> _prepare(ModelInfo model) async {
    if (!isLocalModelRuntimeSource(model.source)) {
      throw LocalModelRuntimeException(
        'Unsupported local model source: ${model.source}. '
        'Choose a .gguf or .litertlm model file.',
      );
    }

    final mmprojPath = resolveLocalMmprojPath(model.mmprojSource);

    final key = '${model.source.trim()}|${model.maxTokens}|${mmprojPath ?? ''}';
    final current = _current;
    final prepared = _prepared;
    if (current != null && prepared != null && _cacheKey == key) {
      return prepared;
    }

    // Switching models, context windows, or projectors: dispose first.
    await _resetCurrent();

    final loaded = await _loader.load(
      LocalRuntimeRequest(
        modelInfo: model,
        contextSize: model.maxTokens,
        constrainedOutput: localModelRuntimeExtension(model.source) == '.gguf',
        mmprojPath: mmprojPath,
      ),
    );
    final nextPrepared = PreparedLocalModel(
      ai: loaded.ai,
      modelRef: loaded.modelRef,
      modelId: loaded.modelId,
    );
    _current = loaded;
    _prepared = nextPrepared;
    _cacheKey = key;
    return nextPrepared;
  }

  @override
  Future<int> countTokens(String text) async => fallbackTokenEstimate(text);

  @override
  void cancelActiveGeneration() {
    _current?.cancel();
  }

  @override
  Future<void> reset() => _serialize(_resetCurrent);

  Future<void> _resetCurrent() async {
    final current = _current;
    _prepared = null;
    _cacheKey = null;
    final disposeFailure = _disposeFailure;
    if (disposeFailure != null) {
      Error.throwWithStackTrace(
        disposeFailure.error,
        disposeFailure.stackTrace,
      );
    }
    if (current != null) {
      try {
        await current.dispose();
      } catch (error, stackTrace) {
        _disposeFailure = (error: error, stackTrace: stackTrace);
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (identical(_current, current)) {
        _current = null;
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then<T>((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}
