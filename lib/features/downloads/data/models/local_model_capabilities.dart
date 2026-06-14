/// App-owned, provider-neutral model capability enums.
///
/// These replace the former third-party model-type / preferred-backend enums.
/// The constant names are chosen so that `.name` produces exactly the
/// strings persisted in Drift (e.g. 'gemma4', 'gemmaIt', 'cpu', 'gpu'), keeping
/// existing user database rows valid.
library;

/// Logical family / runtime template a local model belongs to.
///
/// Each constant's [Enum.name] matches the string value stored in the
/// `ModelInfo.modelType` column.
enum LocalModelType {
  gemma4,
  gemmaIt,
  qwen,
  qwen3,
  deepSeek,
  functionGemma,
  general,
}

/// Preferred inference backend for a local model.
///
/// Each constant's [Enum.name] matches the string value stored in the
/// `ModelInfo.preferredBackend` column.
enum LocalModelBackend { cpu, gpu, npu }

/// Parses a persisted model-type string into a [LocalModelType].
///
/// Falls back to [LocalModelType.general] for unknown values so legacy or
/// malformed rows never crash the catalog.
LocalModelType parseLocalModelType(String value) {
  for (final type in LocalModelType.values) {
    if (type.name == value) return type;
  }
  return LocalModelType.general;
}

/// Parses a persisted backend string into a [LocalModelBackend].
///
/// Returns `null` when [value] is `null` or unrecognized.
LocalModelBackend? parseLocalModelBackend(String? value) {
  if (value == null) return null;
  for (final backend in LocalModelBackend.values) {
    if (backend.name == value) return backend;
  }
  return null;
}
