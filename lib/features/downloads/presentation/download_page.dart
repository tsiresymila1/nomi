import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/providers/download_notifier.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelRepositoryProvider);
    final downloads = ref.watch(downloadProvider);
    final installedModels = ref.watch(modelInstallerProvider);
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Models',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add model',
            onPressed: () => _showAddModelSheet(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: modelsAsync.when(
              data: (models) => installedModels.when(
                data: (installed) => ListView.builder(
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final installKey = downloadNotifier.installKeyForModel(
                      model,
                    );
                    final progress = downloads[installKey];
                    final installedId = downloadNotifier.installedIdForModel(
                      model,
                    );
                    final isInstalled =
                        installed.contains(installedId) || progress == 1.0;

                    return DownloadItem(
                      model: model,
                      progress: progress,
                      isInstalled: isInstalled,
                      onDownload: () {
                        ref.read(downloadProvider.notifier).installModel(model);
                      },
                      onRemove: () {
                        ref.read(downloadProvider.notifier).removeModel(model);
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          if (activeInstall != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Installing ${activeInstall.label}...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (downloads[activeInstall.key] == null)
                          const Center(child: CircularProgressIndicator())
                        else
                          LinearProgressIndicator(
                            value: downloads[activeInstall.key],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddModelSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddModelSheet(
        onSave: (model) async {
          await ref
              .read(modelRepositoryActionsProvider)
              .addModel(
                name: model.name,
                description: model.description,
                modelType: model.modelType,
                sourceType: model.sourceType,
                source: model.source,
              );
        },
      ),
    );
  }
}

class _DraftModel {
  final String name;
  final String description;
  final String modelType;
  final String sourceType;
  final String source;

  const _DraftModel({
    required this.name,
    required this.description,
    required this.modelType,
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
      final path = picked?.files.single.path;
      if (path != null && mounted) {
        _sourceController.text = path;
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File picker is already active')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    if (_sourceType == 'network' &&
        !(source.startsWith('http://') || source.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network source must be a valid URL')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        _DraftModel(
          name: name,
          description: description,
          modelType: _modelType,
          sourceType: _sourceType,
          source: source,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add model',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _modelType,
              decoration: const InputDecoration(labelText: 'Model type'),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sourceController,
                    readOnly: _sourceType == 'file',
                    decoration: InputDecoration(
                      labelText: _sourceType == 'network'
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
                onPressed: _saving ? null : _save,
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
    );
  }
}
