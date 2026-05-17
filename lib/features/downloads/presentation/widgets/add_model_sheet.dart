import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:path_provider/path_provider.dart';

Future<void> showAddModelSheet(
  BuildContext context,
  WidgetRef ref, {
  AnimationController? transitionAnimationController,
  AnimationStyle? sheetAnimationStyle,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    transitionAnimationController: transitionAnimationController,
    sheetAnimationStyle:
        sheetAnimationStyle ??
        const AnimationStyle(
          duration: Duration(milliseconds: 500),
          reverseDuration: Duration(milliseconds: 250),
        ),
    builder: (_) => _AddModelSheet(
      onSave: (model) async {
        await ref
            .read(modelRepositoryActionsProvider)
            .addModel(
              name: model.name,
              description: model.description,
              modelType: model.modelType,
              supportImage: model.supportImage,
              supportAudio: model.supportAudio,
              supportsFunctionCalls: model.supportsFunctionCalls,
              isThinking: model.isThinking,
              sourceType: model.sourceType,
              source: model.source,
            );
      },
    ),
  );
}

class _DraftModel {
  final String name;
  final String description;
  final String modelType;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final String sourceType;
  final String source;

  const _DraftModel({
    required this.name,
    required this.description,
    required this.modelType,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.isThinking,
    required this.sourceType,
    required this.source,
  });
}

class _AddModelSheet extends StatefulWidget {
  final Future<void> Function(_DraftModel model) onSave;

  const _AddModelSheet({required this.onSave});

  @override
  State<_AddModelSheet> createState() => _AddModelSheetState();
}

class _AddModelSheetState extends State<_AddModelSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();

  String _sourceType = 'network';
  String _modelType = ModelType.gemmaIt.name;
  bool _supportImage = false;
  bool _supportAudio = false;
  bool _supportsFunctionCalls = false;
  bool _isThinking = false;
  bool _saving = false;
  bool _picking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['task', 'bin', 'litertlm'],
        dialogTitle: 'Select model file',
      );
      final pickedFile = picked?.files.single;
      if (pickedFile == null || !mounted) return;

      final importedPath = await _copyPickedFileToPersistentFolder(pickedFile);
      if (importedPath == null) {
        if (!mounted) return;
        AppToast.show(
          'Could not import selected file. Please paste an absolute model path manually.',
          type: AppToastType.error,
        );
        return;
      }
      // delete cache
      await FilePicker.platform.clearTemporaryFiles();
      _sourceController.text = importedPath;
    } on PlatformException catch (_) {
      if (!mounted) return;
      AppToast.show('File picker is already active', type: AppToastType.info);
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Import failed: $e', type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();

    if (name.isEmpty || description.isEmpty || source.isEmpty) {
      AppToast.show('All fields are required', type: AppToastType.error);
      return;
    }

    if (_sourceType == 'network' &&
        !(source.startsWith('http://') || source.startsWith('https://'))) {
      AppToast.show(
        'Network source must be a valid URL',
        type: AppToastType.error,
      );
      return;
    }
    if (_sourceType == 'file' && source.startsWith('content://')) {
      AppToast.show(
        'content:// URIs are not absolute paths. Please paste the real model file path.',
        type: AppToastType.error,
      );
      return;
    }

    final normalizedSource = _sourceType == 'file'
        ? _normalizeFileUriToPath(source)
        : source;

    setState(() => _saving = true);
    try {
      await widget.onSave(
        _DraftModel(
          name: name,
          description: description,
          modelType: _modelType,
          supportImage: _supportImage,
          supportAudio: _supportAudio,
          supportsFunctionCalls: _supportsFunctionCalls,
          isThinking: _isThinking,
          sourceType: _sourceType,
          source: normalizedSource,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            spacing: 2,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add model',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Model type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _modelType,
                decoration: const InputDecoration(hintText: 'Model type'),
                items: ModelType.values
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type.name,
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _modelType = value);
                },
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'network', label: Text('URL')),
                  ButtonSegment<String>(value: 'file', label: Text('File')),
                ],
                selected: {_sourceType},
                onSelectionChanged: (value) {
                  setState(() => _sourceType = value.first);
                  _sourceController.clear();
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportImage,
                      title: const Text('Support image'),
                      onChanged: (value) {
                        setState(() => _supportImage = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportAudio,
                      title: const Text('Support audio'),
                      onChanged: (value) {
                        setState(() => _supportAudio = value);
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportsFunctionCalls,
                      title: const Text('Function calls'),
                      onChanged: (value) {
                        setState(() => _supportsFunctionCalls = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isThinking,
                      title: const Text('Thinking mode'),
                      onChanged: (value) {
                        setState(() => _isThinking = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        hintText: _sourceType == 'network'
                            ? 'Model URL'
                            : 'Model file path',
                      ),
                    ),
                  ),
                  if (_sourceType == 'file') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _picking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open),
                      onPressed: _picking ? null : _pickFile,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving | _picking ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save model'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeFileUriToPath(String input) {
    if (!input.startsWith('file://')) return input;
    try {
      return Uri.parse(input).toFilePath();
    } catch (_) {
      return input.replaceFirst('file://', '');
    }
  }

  Future<String?> _copyPickedFileToPersistentFolder(
    PlatformFile pickedFile,
  ) async {
    final sourcePath = pickedFile.path?.trim();
    if (sourcePath == null || sourcePath.isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final appSupportDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appSupportDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final originalName = pickedFile.name.trim().isEmpty
        ? 'model.bin'
        : pickedFile.name.trim();
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final targetPath =
        '${modelsDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final copied = await sourceFile.copy(targetPath);
    return copied.path;
  }
}
