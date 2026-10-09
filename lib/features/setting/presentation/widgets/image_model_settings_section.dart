import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/downloads/data/services/direct_model_file_picker.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';

typedef ImageModelPathPicker = Future<String?> Function();
typedef ImageModelFileSizeResolver = Future<int> Function(String path);

class ImageModelSettingsSection extends StatefulWidget {
  const ImageModelSettingsSection({
    super.key,
    required this.selectionCubit,
    required this.generationCubit,
    this.pathPicker,
    this.fileSizeResolver,
  });

  final ImageModelSelectionCubit selectionCubit;
  final ImageGenerationCubit generationCubit;
  final ImageModelPathPicker? pathPicker;
  final ImageModelFileSizeResolver? fileSizeResolver;

  @override
  State<ImageModelSettingsSection> createState() =>
      _ImageModelSettingsSectionState();
}

class _ImageModelSettingsSectionState extends State<ImageModelSettingsSection> {
  @override
  void initState() {
    super.initState();
    if (widget.generationCubit.state.phase == ImageGenerationUiPhase.initial) {
      widget.generationCubit.initialize();
    }
  }

  Future<void> _select(ImageModelProfile profile) async {
    final selection = widget.selectionCubit;
    if (selection.state.selectedId == profile.id) return;
    final current = selection.state.selectedProfile;
    final warning = profile.deviceTier == ImageModelDeviceTier.recommended4Gb
        ? ''
        : '\n\nThis model can be slower and may exceed the memory available on a 4 GB device.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Use ${profile.name}?'),
        content: Text(
          'Switch from ${current.name} to ${profile.name}. The current local AI engine will be released.$warning',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Use model'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (widget.generationCubit.state.phase ==
            ImageGenerationUiPhase.downloading ||
        widget.generationCubit.state.phase ==
            ImageGenerationUiPhase.verifying) {
      await widget.generationCubit.cancelInstall();
    }
    widget.generationCubit.cancelGeneration();
    selection.select(profile.id);
    await widget.generationCubit.refreshForSelectedModel();
  }

  Future<void> _registerExternal() => _pickExternal();

  Future<void> _relocateExternal(ImageModelProfile profile) =>
      _pickExternal(replacing: profile);

  Future<void> _pickExternal({ImageModelProfile? replacing}) async {
    try {
      final path =
          await (widget.pathPicker?.call() ??
              DirectModelFilePicker.pickModelPath(
                allowedExtensions: const <String>['gguf'],
                dialogTitle: 'Select Stable Diffusion GGUF',
              ));
      if (path == null || !mounted) return;
      if (!path.toLowerCase().endsWith('.gguf')) {
        throw const DirectModelFilePickerException(
          'Choose a .gguf image model file.',
        );
      }
      final size =
          await (widget.fileSizeResolver?.call(path) ?? File(path).length());
      if (size <= 0) {
        throw const DirectModelFilePickerException(
          'The selected GGUF file is empty.',
        );
      }
      final fileName = path.split(RegExp(r'[/\\]')).last;
      final name = fileName.replaceFirst(
        RegExp(r'\.gguf$', caseSensitive: false),
        '',
      );
      final profile = widget.selectionCubit.registerExternal(
        name: name,
        filePath: path,
        sizeBytes: size,
      );
      widget.selectionCubit.select(profile.id);
      if (replacing != null && replacing.id != profile.id) {
        widget.selectionCubit.removeCustom(replacing.id);
      }
      await widget.generationCubit.refreshForSelectedModel();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Model import failed: $error')));
    }
  }

  Future<void> _removeCustom(ImageModelProfile profile) async {
    widget.selectionCubit.removeCustom(profile.id);
    await widget.generationCubit.refreshForSelectedModel();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageModelSelectionCubit, ImageModelSelectionState>(
      bloc: widget.selectionCubit,
      builder: (context, selectionState) {
        return BlocBuilder<ImageGenerationCubit, ImageGenerationState>(
          bloc: widget.generationCubit,
          builder: (context, generationState) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ListTile(
                      leading: Icon(Icons.auto_awesome_rounded),
                      title: Text('Image generation'),
                      subtitle: Text(
                        'Choose the GGUF model used by every chat.',
                      ),
                    ),
                    for (final profile in selectionState.allProfiles)
                      _ImageModelTile(
                        profile: profile,
                        selected: selectionState.selectedId == profile.id,
                        generationState: generationState,
                        onTap: () => _select(profile),
                        onRemove: profile.isExternal
                            ? () => _removeCustom(profile)
                            : null,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: OutlinedButton.icon(
                        onPressed: _registerExternal,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Add GGUF model'),
                      ),
                    ),
                    if (generationState.profile.id == selectionState.selectedId)
                      _SelectedModelAction(
                        state: generationState,
                        onInstall: widget.generationCubit.installModel,
                        onCancelInstall: widget.generationCubit.cancelInstall,
                        onRemove: widget.generationCubit.removeModel,
                        onLocate: () =>
                            _relocateExternal(selectionState.selectedProfile),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ImageModelTile extends StatelessWidget {
  const _ImageModelTile({
    required this.profile,
    required this.selected,
    required this.generationState,
    required this.onTap,
    this.onRemove,
  });

  final ImageModelProfile profile;
  final bool selected;
  final ImageGenerationState generationState;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final badge = switch (profile.deviceTier) {
      ImageModelDeviceTier.recommended4Gb => 'Recommended for 4 GB',
      ImageModelDeviceTier.experimental => 'Experimental',
      ImageModelDeviceTier.custom => 'Custom',
    };
    final selectedStatus = selected && generationState.profile.id == profile.id
        ? switch (generationState.phase) {
            ImageGenerationUiPhase.ready ||
            ImageGenerationUiPhase.completed ||
            ImageGenerationUiPhase.cancelled => ' · Installed',
            ImageGenerationUiPhase.downloading =>
              ' · ${(generationState.downloadProgress * 100).round()}%',
            ImageGenerationUiPhase.needsInstall =>
              profile.isExternal ? ' · File unavailable' : ' · Not installed',
            _ => '',
          }
        : '';
    return ListTile(
      onTap: onTap,
      title: Text(profile.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(badge), Text('${profile.displaySize}$selectedStatus')],
      ),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove from list',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
    );
  }
}

class _SelectedModelAction extends StatelessWidget {
  const _SelectedModelAction({
    required this.state,
    required this.onInstall,
    required this.onCancelInstall,
    required this.onRemove,
    required this.onLocate,
  });

  final ImageGenerationState state;
  final VoidCallback onInstall;
  final VoidCallback onCancelInstall;
  final VoidCallback onRemove;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    if (state.profile.isExternal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: OutlinedButton.icon(
          onPressed: state.isBusy ? null : onLocate,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Locate again'),
        ),
      );
    }
    if (state.phase == ImageGenerationUiPhase.downloading ||
        state.phase == ImageGenerationUiPhase.verifying) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: state.phase == ImageGenerationUiPhase.downloading
                  ? state.downloadProgress
                  : null,
            ),
            TextButton(
              onPressed: onCancelInstall,
              child: const Text('Cancel download'),
            ),
          ],
        ),
      );
    }
    final installed = state.isInstalled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: OutlinedButton.icon(
        onPressed: state.isBusy
            ? null
            : installed
            ? onRemove
            : onInstall,
        icon: Icon(
          installed ? Icons.delete_outline_rounded : Icons.download_rounded,
        ),
        label: Text(installed ? 'Remove downloaded model' : 'Download model'),
      ),
    );
  }
}
