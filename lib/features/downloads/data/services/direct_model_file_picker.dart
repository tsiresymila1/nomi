import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class DirectModelFilePickerException implements Exception {
  const DirectModelFilePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Selects an existing model without copying it into app-owned storage.
///
/// Android uses a native picker after the user grants all-files access so the
/// native inference runtime receives a stable filesystem path. Cloud/document
/// providers that only expose `content://` streams are intentionally rejected.
class DirectModelFilePicker {
  const DirectModelFilePicker._();

  static const MethodChannel _androidChannel = MethodChannel(
    'gena/direct_model_files',
  );

  static Future<String?> pickModelPath({
    List<String> allowedExtensions = const <String>['gguf', 'litertlm'],
    String dialogTitle = 'Select model file',
  }) async {
    if (!Platform.isAndroid) {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle,
      );
      final path = picked?.files.single.path;
      if (path != null) _validateExtension(path, allowedExtensions);
      return path;
    }

    try {
      final hasAccess =
          await _androidChannel.invokeMethod<bool>('hasAllFilesAccess') ??
          false;
      if (!hasAccess) {
        final granted =
            await _androidChannel.invokeMethod<bool>('requestAllFilesAccess') ??
            false;
        if (!granted) {
          throw const DirectModelFilePickerException(
            'File access is required to use a GGUF directly without copying it.',
          );
        }
      }

      final path = await _androidChannel.invokeMethod<String>('pickModelFile');
      if (path != null) _validateExtension(path, allowedExtensions);
      return path;
    } on PlatformException catch (error) {
      throw DirectModelFilePickerException(
        error.message ?? 'The selected provider has no direct file path.',
      );
    }
  }

  static void _validateExtension(String path, List<String> allowedExtensions) {
    final normalized = path.toLowerCase();
    final allowed = allowedExtensions.any(
      (extension) => normalized.endsWith('.${extension.toLowerCase()}'),
    );
    if (!allowed) {
      throw DirectModelFilePickerException(
        'Choose a ${allowedExtensions.map((item) => '.$item').join(' or ')} model file.',
      );
    }
  }
}
