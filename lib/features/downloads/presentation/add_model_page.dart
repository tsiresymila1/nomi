import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_slider_tile.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:path_provider/path_provider.dart';

class AddModelPage extends ConsumerStatefulWidget {
  final ModelInfo? initialModel;

  const AddModelPage({super.key, this.initialModel});

  @override
  ConsumerState<AddModelPage> createState() => _AddModelPageState();
}

class _AddModelPageState extends ConsumerState<AddModelPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();

  String _sourceType = 'network';
  String _modelType = ModelType.gemma4.name;
  String _preferredBackend = 'gpu';
  double _temperature = 0.8;
  double _topP = 0.95;
  int _topK = 40;
  int _maxTokens = 2048;
  int _tokenBuffer = 256;
  int _randomSeed = 1;

  bool _supportImage = false;
  bool _supportAudio = false;
  bool _supportsFunctionCalls = false;
  bool _isThinking = false;

  bool _saving = false;
  bool _picking = false;
  late final bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.initialModel != null;
    final model = widget.initialModel;
    if (model == null) return;

    _nameController.text = model.name;
    _descriptionController.text = model.description;
    _sourceController.text = model.source;
    _sourceType = model.sourceType;
    _modelType = model.modelType;
    _preferredBackend = model.preferredBackend;
    _temperature = model.temperature;
    _topP = model.topP;
    _topK = model.topK;
    _maxTokens = model.maxTokens;
    _tokenBuffer = model.tokenBuffer;
    _randomSeed = model.randomSeed;
    _supportImage = model.supportImage;
    _supportAudio = model.supportAudio;
    _supportsFunctionCalls = model.supportsFunctionCalls;
    _isThinking = model.isThinking;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  int _resolveTokenBufferMax(int maxTokens) {
    final candidate = maxTokens - 1;
    if (candidate < 32) return 32;
    return candidate > 4096 ? 4096 : candidate;
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
    if (_tokenBuffer >= _maxTokens) {
      AppToast.show(
        'Token buffer must be smaller than max tokens',
        type: AppToastType.error,
      );
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
      final actions = ref.read(modelRepositoryActionsProvider);
      if (_isEditMode) {
        await actions.updateModel(
          id: widget.initialModel!.id,
          name: name,
          description: description,
          modelType: _modelType,
          supportImage: _supportImage,
          supportAudio: _supportAudio,
          supportsFunctionCalls: _supportsFunctionCalls,
          isThinking: _isThinking,
          temperature: _temperature,
          topK: _topK,
          topP: _topP,
          maxTokens: _maxTokens,
          tokenBuffer: _tokenBuffer,
          randomSeed: _randomSeed,
          preferredBackend: _preferredBackend,
          sourceType: _sourceType,
          source: normalizedSource,
        );
      } else {
        await actions.addModel(
          name: name,
          description: description,
          modelType: _modelType,
          supportImage: _supportImage,
          supportAudio: _supportAudio,
          supportsFunctionCalls: _supportsFunctionCalls,
          isThinking: _isThinking,
          temperature: _temperature,
          topK: _topK,
          topP: _topP,
          maxTokens: _maxTokens,
          tokenBuffer: _tokenBuffer,
          randomSeed: _randomSeed,
          preferredBackend: _preferredBackend,
          sourceType: _sourceType,
          source: normalizedSource,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.show('Save failed: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenBufferMax = _resolveTokenBufferMax(_maxTokens);
    if (_tokenBuffer > tokenBufferMax) {
      _tokenBuffer = tokenBufferMax;
    }

    Widget reveal(int index, Widget child) {
      final delay = (index * 55).ms;
      return child
          .animate(key: ValueKey('add-model-item-$index'))
          .fadeIn(duration: 320.ms, delay: delay)
          .slideY(begin: 0.06, end: 0, duration: 260.ms, delay: delay);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit model' : 'Add model',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            reveal(
              0,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Name'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            reveal(
              1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(hintText: 'Description'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            reveal(
              2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Model type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _modelType,
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            reveal(
              3,
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
            ),
            const SizedBox(height: 8),
            reveal(
              4,
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportImage,
                      title: const Text('Support image'),
                      onChanged: (value) =>
                          setState(() => _supportImage = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportAudio,
                      title: const Text('Support audio'),
                      onChanged: (value) =>
                          setState(() => _supportAudio = value),
                    ),
                  ),
                ],
              ),
            ),
            reveal(
              5,
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _supportsFunctionCalls,
                      title: const Text('Function calls'),
                      onChanged: (value) =>
                          setState(() => _supportsFunctionCalls = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isThinking,
                      title: const Text('Thinking default'),
                      onChanged: (value) => setState(() => _isThinking = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            reveal(
              6,
              ModelSettingsSliderTile(
                label: 'Temperature',
                valueText: _temperature.toStringAsFixed(2),
                slider: Slider(
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 40,
                  onChanged: (value) => setState(() => _temperature = value),
                ),
              ),
            ),
            reveal(
              7,
              ModelSettingsSliderTile(
                label: 'Top-P',
                valueText: _topP.toStringAsFixed(2),
                slider: Slider(
                  value: _topP,
                  min: 0.1,
                  max: 1,
                  divisions: 18,
                  onChanged: (value) => setState(() => _topP = value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            reveal(
              8,
              ModelSettingsSliderTile(
                label: 'Top-K',
                valueText: _topK.toString(),
                slider: Slider(
                  value: _topK.toDouble(),
                  min: 1,
                  max: 200,
                  divisions: 199,
                  onChanged: (value) => setState(() => _topK = value.round()),
                ),
              ),
            ),
            reveal(
              9,
              ModelSettingsSliderTile(
                label: 'Max tokens',
                valueText: _maxTokens.toString(),
                slider: Slider(
                  value: _maxTokens.toDouble(),
                  min: 256,
                  max: 8192,
                  divisions: 248,
                  onChanged: (value) {
                    setState(() {
                      _maxTokens = value.round();
                      final maxAllowed = _resolveTokenBufferMax(_maxTokens);
                      if (_tokenBuffer > maxAllowed) {
                        _tokenBuffer = maxAllowed;
                      }
                    });
                  },
                ),
              ),
            ),
            reveal(
              10,
              ModelSettingsSliderTile(
                label: 'Token buffer',
                valueText: _tokenBuffer.toString(),
                slider: Slider(
                  value: _tokenBuffer.toDouble(),
                  min: 32,
                  max: tokenBufferMax.toDouble(),
                  divisions: tokenBufferMax > 32 ? tokenBufferMax - 32 : 1,
                  onChanged: (value) =>
                      setState(() => _tokenBuffer = value.round()),
                ),
              ),
            ),
            reveal(
              11,
              ModelSettingsSliderTile(
                label: 'Random seed',
                valueText: _randomSeed.toString(),
                slider: Slider(
                  value: _randomSeed.toDouble(),
                  min: 0,
                  max: 10000,
                  divisions: 10000,
                  onChanged: (value) =>
                      setState(() => _randomSeed = value.round()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            reveal(
              12,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferred backend',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _preferredBackend,
                    decoration: const InputDecoration(
                      hintText: 'Preferred backend',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto')),
                      DropdownMenuItem(value: 'gpu', child: Text('GPU')),
                      DropdownMenuItem(value: 'cpu', child: Text('CPU')),
                      DropdownMenuItem(value: 'npu', child: Text('NPU')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _preferredBackend = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_sourceType == 'file')
              reveal(
                13,

                FilledButton.icon(
                  onPressed: _picking ? null : _pickFile,
                  icon: _picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  label: const Text('Choose file'),
                ),
              ),
            if (_sourceType == 'file') const SizedBox(height: 8),
            reveal(
              14,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sourceType == 'network' ? 'URL source' : 'File path',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      hintText: _sourceType == 'network'
                          ? 'https://...'
                          : '/absolute/path/model.task',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            reveal(
              15,
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || _picking ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditMode ? 'Update model' : 'Save model'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _copyPickedFileToPersistentFolder(
    PlatformFile pickedFile,
  ) async {
    final sourcePath = pickedFile.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final appSupportDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appSupportDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final filename = pickedFile.name.trim().isEmpty
        ? sourceFile.uri.pathSegments.last
        : pickedFile.name;
    final safeFilename = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final targetPath =
        '${modelsDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeFilename';
    final copied = await sourceFile.copy(targetPath);
    return copied.path;
  }

  String _normalizeFileUriToPath(String source) {
    if (source.startsWith('file://')) {
      final uri = Uri.tryParse(source);
      if (uri != null && uri.scheme == 'file') {
        return uri.toFilePath();
      }
    }
    return source;
  }
}
