import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_number_field.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_slider_tile.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
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
  final _apiUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _outputTokensController = TextEditingController();

  String _providerType = ModelProviderType.local;
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
    if (model == null) {
      _syncTokenControllers();
      return;
    }

    _nameController.text = model.name;
    _descriptionController.text = model.description;
    _sourceController.text = model.source;
    _apiUrlController.text = model.apiUrl ?? '';
    _apiTokenController.text = model.apiToken ?? '';
    _providerType = model.provider;
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
    _syncTokenControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    _apiUrlController.dispose();
    _apiTokenController.dispose();
    _maxTokensController.dispose();
    _outputTokensController.dispose();
    super.dispose();
  }

  int _resolveMaxTokensMax() {
    if (_providerType == ModelProviderType.remote) return 1000000;
    return 8192;
  }

  int _resolveMaxTokensMin() {
    if (_providerType == ModelProviderType.remote) return 1;
    return 256;
  }

  int _resolveTokenBufferMin() {
    if (_providerType == ModelProviderType.remote) return 1;
    return 32;
  }

  int _resolveTokenBufferMax(int maxTokens) {
    if (_providerType == ModelProviderType.remote) {
      if (maxTokens < 1) return 1;
      return maxTokens;
    }
    final candidate = maxTokens - 1;
    if (candidate < 32) return 32;
    return candidate > 4096 ? 4096 : candidate;
  }

  void _syncTokenControllers() {
    _maxTokensController.text = _maxTokens.toString();
    _outputTokensController.text = _tokenBuffer.toString();
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
    final apiUrl = _apiUrlController.text.trim();
    final apiToken = _apiTokenController.text.trim();

    if (_providerType == ModelProviderType.remote) {
      final parsedMaxTokens = int.tryParse(_maxTokensController.text.trim());
      final parsedOutputTokens = int.tryParse(
        _outputTokensController.text.trim(),
      );
      if (parsedMaxTokens == null || parsedOutputTokens == null) {
        AppToast.show(
          'Max tokens and output tokens must be valid numbers',
          type: AppToastType.error,
        );
        return;
      }
      _maxTokens = parsedMaxTokens;
      _tokenBuffer = parsedOutputTokens;
    }

    if (name.isEmpty || description.isEmpty) {
      AppToast.show('All fields are required', type: AppToastType.error);
      return;
    }

    final minTokens = _resolveMaxTokensMin();
    final maxTokensLimit = _resolveMaxTokensMax();
    if (_maxTokens < minTokens || _maxTokens > maxTokensLimit) {
      AppToast.show(
        'Max tokens must be between $minTokens and $maxTokensLimit',
        type: AppToastType.error,
      );
      return;
    }

    final minOutputTokens = _resolveTokenBufferMin();
    final maxOutputTokens = _resolveTokenBufferMax(_maxTokens);
    if (_tokenBuffer < minOutputTokens || _tokenBuffer > maxOutputTokens) {
      AppToast.show(
        _providerType == ModelProviderType.remote
            ? 'Output tokens must be between $minOutputTokens and $maxOutputTokens'
            : 'Output tokens must be between $minOutputTokens and $maxOutputTokens',
        type: AppToastType.error,
      );
      return;
    }

    if (_providerType == ModelProviderType.local &&
        _tokenBuffer >= _maxTokens) {
      AppToast.show(
        'Output tokens must be smaller than max tokens for local models',
        type: AppToastType.error,
      );
      return;
    }

    if (_providerType == ModelProviderType.local) {
      if (source.isEmpty) {
        AppToast.show(
          'Source is required for local models',
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
    } else {
      if (apiUrl.isEmpty || apiToken.isEmpty) {
        AppToast.show(
          'API URL and token are required for remote models',
          type: AppToastType.error,
        );
        return;
      }
      if (!(apiUrl.startsWith('http://') || apiUrl.startsWith('https://'))) {
        AppToast.show(
          'API URL must start with http:// or https://',
          type: AppToastType.error,
        );
        return;
      }
    }

    final normalizedSource =
        _providerType == ModelProviderType.local && _sourceType == 'file'
        ? _normalizeFileUriToPath(source)
        : (_providerType == ModelProviderType.local
              ? source
              : (source.isEmpty ? 'remote://chat' : source));
    final sourceType = _providerType == ModelProviderType.local
        ? _sourceType
        : 'remote';

    setState(() => _saving = true);
    try {
      final actions = ref.read(modelRepositoryActionsProvider);
      if (_isEditMode) {
        await actions.updateModel(
          id: widget.initialModel!.id,
          name: name,
          description: description,
          provider: _providerType,
          apiUrl: _providerType == ModelProviderType.remote ? apiUrl : null,
          apiToken: _providerType == ModelProviderType.remote ? apiToken : null,
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
          sourceType: sourceType,
          source: normalizedSource,
        );
      } else {
        await actions.addModel(
          name: name,
          description: description,
          provider: _providerType,
          apiUrl: _providerType == ModelProviderType.remote ? apiUrl : null,
          apiToken: _providerType == ModelProviderType.remote ? apiToken : null,
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
          sourceType: sourceType,
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
    final tokenBufferMin = _resolveTokenBufferMin();
    if (_tokenBuffer > tokenBufferMax) {
      _tokenBuffer = tokenBufferMax;
      _syncTokenControllers();
    }
    if (_tokenBuffer < tokenBufferMin) {
      _tokenBuffer = tokenBufferMin;
      _syncTokenControllers();
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
          spacing: 2,
          children: [
            reveal(
              0,
              FieldWrapper(
                label: 'Name',
                field: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Name'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            reveal(
              1,
              FieldWrapper(
                label: "Description",
                field: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(hintText: 'Description'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            reveal(
              2,
              FieldWrapper(
                label: 'Model type',
                field: DropdownButtonFormField<String>(
                  initialValue: _modelType,
                  style: TextStyle(fontSize: 14),
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
              ),
            ),
            const SizedBox(height: 8),

            reveal(
              5,
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
              6,
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
              7,
              ModelSettingsSliderTile(
                label: 'Temperature',
                valueText: _temperature.toStringAsFixed(2),
                slider: Slider(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 40,
                  onChanged: (value) => setState(() => _temperature = value),
                ),
              ),
            ),
            reveal(
              8,
              ModelSettingsSliderTile(
                label: 'Top-P',
                valueText: _topP.toStringAsFixed(2),
                slider: Slider(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
              9,
              ModelSettingsSliderTile(
                label: 'Top-K',
                valueText: _topK.toString(),
                slider: Slider(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  value: _topK.toDouble(),
                  min: 1,
                  max: 200,
                  divisions: 199,
                  onChanged: (value) => setState(() => _topK = value.round()),
                ),
              ),
            ),
            if (_providerType == ModelProviderType.local)
              reveal(
                10,
                ModelSettingsSliderTile(
                  label: 'Max tokens',
                  valueText: _maxTokens.toString(),
                  slider: Slider(
                    padding: EdgeInsets.symmetric(vertical: 12),
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
                        _syncTokenControllers();
                      });
                    },
                  ),
                ),
              ),
            if (_providerType == ModelProviderType.local)
              reveal(
                11,
                ModelSettingsSliderTile(
                  label: 'Output tokens',
                  valueText: _tokenBuffer.toString(),
                  slider: Slider(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    value: _tokenBuffer.toDouble(),
                    min: tokenBufferMin.toDouble(),
                    max: tokenBufferMax.toDouble(),
                    divisions: tokenBufferMax > tokenBufferMin
                        ? tokenBufferMax - tokenBufferMin
                        : 1,
                    onChanged: (value) => setState(() {
                      _tokenBuffer = value.round();
                      _syncTokenControllers();
                    }),
                  ),
                ),
              ),
            if (_providerType == ModelProviderType.remote)
              reveal(
                10,
                Column(
                  children: [
                    ModelSettingsNumberField(
                      controller: _maxTokensController,
                      label: 'Max tokens (context, up to 1,000,000)',
                    ),
                    const SizedBox(height: 8),
                    ModelSettingsNumberField(
                      controller: _outputTokensController,
                      label: 'Output tokens',
                    ),
                  ],
                ),
              ),
            reveal(
              12,
              ModelSettingsSliderTile(
                label: 'Random seed',
                valueText: _randomSeed.toString(),
                slider: Slider(
                  padding: EdgeInsets.symmetric(vertical: 12),
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
              3,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: ModelProviderType.local,
                    label: Text('Local'),
                  ),
                  ButtonSegment<String>(
                    value: ModelProviderType.remote,
                    label: Text('Remote API'),
                  ),
                ],
                selected: {_providerType},
                onSelectionChanged: (value) {
                  setState(() {
                    _providerType = value.first;
                    final minTokens = _resolveMaxTokensMin();
                    final maxTokens = _resolveMaxTokensMax();
                    if (_maxTokens < minTokens) _maxTokens = minTokens;
                    if (_maxTokens > maxTokens) _maxTokens = maxTokens;
                    final maxOutput = _resolveTokenBufferMax(_maxTokens);
                    final minOutput = _resolveTokenBufferMin();
                    if (_tokenBuffer < minOutput) _tokenBuffer = minOutput;
                    if (_tokenBuffer > maxOutput) _tokenBuffer = maxOutput;
                    _syncTokenControllers();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_providerType == ModelProviderType.local)
              reveal(
                4,
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
            if (_providerType == ModelProviderType.local)
              const SizedBox(height: 8),
            if (_providerType == ModelProviderType.local)
              reveal(
                13,
                FieldWrapper(
                  label: 'Preferred backend',
                  field: DropdownButtonFormField<String>(
                    initialValue: _preferredBackend,
                    style: TextStyle(fontSize: 14),
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
                ),
              ),
            const SizedBox(height: 12),
            if (_providerType == ModelProviderType.local &&
                _sourceType == 'file')
              reveal(
                14,

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
            if (_providerType == ModelProviderType.local &&
                _sourceType == 'file')
              const SizedBox(height: 8),
            if (_providerType == ModelProviderType.local)
              reveal(
                15,
                FieldWrapper(
                  label: _sourceType == 'network' ? 'URL source' : 'File path',
                  field: TextField(
                    controller: _sourceController,
                    decoration: InputDecoration(
                      hintText: _sourceType == 'network'
                          ? 'https://...'
                          : '/absolute/path/model.task',
                    ),
                  ),
                ),
              ),
            if (_providerType == ModelProviderType.remote)
              reveal(
                16,
                Column(
                  spacing: 10,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldWrapper(
                      label: 'API URL',
                      field: TextField(
                        controller: _apiUrlController,
                        decoration: const InputDecoration(
                          hintText: 'https://api.example.com/v1',
                        ),
                      ),
                    ),
                    FieldWrapper(
                      label: 'API Token',
                      field: TextField(
                        controller: _apiTokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Bearer token',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            reveal(
              17,
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
