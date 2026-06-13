import 'dart:io';

const supportedLocalModelExtensions = <String>{'.gguf', '.litertlm'};

bool isCompatibleLocalModelSource(String source) {
  return localModelSourceValidationError(source) == null;
}

String? localModelSourceValidationError(String source) {
  final extension = localModelSourceExtension(source);
  if (extension == null) {
    return 'Model source must end with .gguf or .litertlm.';
  }
  if (supportedLocalModelExtensions.contains(extension)) return null;
  if (extension == '.task') {
    return '.task models are no longer supported. Choose a .gguf or .litertlm model file.';
  }
  return '$extension model files are not supported. Choose a .gguf or .litertlm model file.';
}

String? localModelSourceExtension(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  final path = uri != null && uri.hasScheme ? uri.path : trimmed;
  final fileName = path.split(RegExp(r'[/\\]')).last.toLowerCase();
  final extensionIndex = fileName.lastIndexOf('.');
  if (extensionIndex < 0) return null;
  return fileName.substring(extensionIndex);
}

String canonicalLocalModelPath(String path) {
  final trimmed = path.trim();
  final uri = Uri.tryParse(trimmed);
  final filePath = uri != null && uri.scheme == 'file'
      ? uri.toFilePath()
      : trimmed;
  final canonical = File(filePath).absolute.uri.normalizePath().toFilePath();
  return Platform.isWindows ? canonical.toLowerCase() : canonical;
}

String localModelIdForPath(String path) {
  return 'local-file:${Uri.encodeComponent(canonicalLocalModelPath(path))}';
}

bool isPathWithinDirectory({required String path, required String directory}) {
  final canonicalPath = canonicalLocalModelPath(path);
  final canonicalDirectory = canonicalLocalModelPath(directory);
  final separator = Platform.pathSeparator;
  return canonicalPath == canonicalDirectory ||
      canonicalPath.startsWith('$canonicalDirectory$separator');
}
