import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/llamadart_tts_model_cubit.dart';
import 'package:gena/features/downloads/data/services/direct_model_file_picker.dart';
import 'package:gena/features/setting/presentation/cubit/text_to_speech_settings_cubit.dart';

typedef TtsModelPathPicker = Future<String?> Function();

class TextToSpeechSettingsSection extends StatefulWidget {
  const TextToSpeechSettingsSection({
    super.key,
    required this.cubit,
    required this.textToSpeech,
    this.llamaDartCubit,
    this.initiallyExpanded = false,
    this.ttsModelPathPicker,
    this.ttsProjectorPathPicker,
    TextToSpeech? playback,
  }) : playback = playback ?? textToSpeech;

  final TextToSpeechSettingsCubit cubit;
  final FlutterTextToSpeech textToSpeech;
  final LlamaDartTtsModelCubit? llamaDartCubit;
  final TextToSpeech playback;
  final bool initiallyExpanded;
  final TtsModelPathPicker? ttsModelPathPicker;
  final TtsModelPathPicker? ttsProjectorPathPicker;

  @override
  State<TextToSpeechSettingsSection> createState() =>
      _TextToSpeechSettingsSectionState();
}

class _TextToSpeechSettingsSectionState
    extends State<TextToSpeechSettingsSection> {
  List<String> _engines = const <String>[];
  List<TextToSpeechVoice> _voices = const <TextToSpeechVoice>[];
  bool _loading = true;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    final llamaDartCubit = widget.llamaDartCubit;
    if (llamaDartCubit != null) unawaited(_initializeLlamaDart(llamaDartCubit));
  }

  Future<void> _initializeLlamaDart(
    LlamaDartTtsModelCubit llamaDartCubit,
  ) async {
    await llamaDartCubit.initialize();
    if (widget.cubit.state.backend == TextToSpeechBackend.llamaDart) {
      await llamaDartCubit.activate();
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _loading = true);
    final engines = await widget.textToSpeech.availableEngines();
    final voices = await widget.textToSpeech.availableVoices();
    if (!mounted) return;
    setState(() {
      _engines = engines;
      _voices = voices;
      _loading = false;
    });
  }

  Future<void> _apply() async {
    try {
      await widget.textToSpeech.applyPreferences(
        widget.cubit.state.preferences,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _selectEngine(String? engine) async {
    if (engine == null) return;
    widget.cubit.selectEngine(engine);
    await _apply();
    final voices = await widget.textToSpeech.availableVoices();
    if (mounted) setState(() => _voices = voices);
  }

  Future<void> _showVoicePicker(TextToSpeechSettingsState state) async {
    if (_voices.isEmpty) return;
    final selected = await showModalBottomSheet<TextToSpeechVoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'TTS voice',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Offline high-quality voices are recommended on mobile.',
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _voices.length,
                  itemBuilder: (context, index) {
                    final voice = _voices[index];
                    final isSelected =
                        voice.name == state.voiceName &&
                        voice.locale == state.voiceLocale;
                    final recommended = voice.isOffline && voice.isHighQuality;
                    return ListTile(
                      selected: isSelected,
                      leading: Icon(
                        voice.isOffline
                            ? Icons.offline_bolt_outlined
                            : Icons.cloud_outlined,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(voice.locale)),
                          if (recommended) ...[
                            const SizedBox(width: 8),
                            const Badge(label: Text('Recommended')),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${voice.name}\n${voice.quality} quality · ${voice.latency} latency',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Test voice',
                            onPressed: () => _previewVoice(voice),
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                          if (isSelected) const Icon(Icons.check_rounded),
                        ],
                      ),
                      onTap: () => Navigator.pop(context, voice),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await widget.textToSpeech.stop();
    if (selected != null) widget.cubit.selectVoice(selected);
    await _apply();
  }

  Future<void> _previewVoice(TextToSpeechVoice voice) async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      final state = widget.cubit.state;
      await widget.textToSpeech.applyPreferences(
        TextToSpeechPreferences(
          engine: state.engine,
          voiceName: voice.name,
          voiceLocale: voice.locale,
          speechRate: state.speechRate,
          pitch: state.pitch,
        ),
      );
      await widget.textToSpeech.speak(
        'Bonjour, ceci est un aperçu de cette voix.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      await _apply();
      await widget.playback.speak(
        'Bonjour, ceci est un aperçu de la voix sélectionnée.',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _selectBackend(TextToSpeechBackend backend) async {
    if (backend == widget.cubit.state.backend) return;
    final llamaDartCubit = widget.llamaDartCubit;
    if (backend == TextToSpeechBackend.llamaDart) {
      if (llamaDartCubit == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Use Local AI voice?'),
          content: const Text(
            'Qwen3-TTS uses about 1.5 GB of model files and is designed for '
            'devices with at least 6 GB RAM. On a 4 GB device it is '
            'experimental and chat models will be released while it speaks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use Local AI'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.playback.stop();
      widget.cubit.selectBackend(backend);
      await llamaDartCubit.activate();
      return;
    }
    await widget.playback.stop();
    widget.cubit.selectBackend(backend);
    await llamaDartCubit?.deactivate();
  }

  Future<void> _addExternalTtsModel() async {
    final cubit = widget.llamaDartCubit;
    if (cubit == null) return;
    try {
      final modelPath =
          await (widget.ttsModelPathPicker?.call() ??
              DirectModelFilePicker.pickModelPath(
                allowedExtensions: const <String>['gguf'],
                dialogTitle: 'Select Qwen3-TTS GGUF',
              ));
      if (modelPath == null || !mounted) return;
      final projectorPath =
          await (widget.ttsProjectorPathPicker?.call() ??
              DirectModelFilePicker.pickModelPath(
                allowedExtensions: const <String>['gguf'],
                dialogTitle: 'Select Qwen3-TTS mmproj GGUF',
              ));
      if (projectorPath == null || !mounted) return;
      if (!modelPath.toLowerCase().endsWith('.gguf') ||
          !projectorPath.toLowerCase().endsWith('.gguf')) {
        throw const DirectModelFilePickerException(
          'Choose both the Qwen3-TTS model and its .gguf projector.',
        );
      }
      final modelSize = await File(modelPath).length();
      final projectorSize = await File(projectorPath).length();
      if (modelSize <= 0 || projectorSize <= 0) {
        throw const DirectModelFilePickerException(
          'The selected TTS model files are empty.',
        );
      }
      final modelName = modelPath
          .split(RegExp(r'[/\\]'))
          .last
          .replaceFirst(RegExp(r'\.gguf$', caseSensitive: false), '');
      await cubit.registerExternal(
        name: modelName,
        modelPath: modelPath,
        modelSizeBytes: modelSize,
        projectorPath: projectorPath,
        projectorSizeBytes: projectorSize,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS model import failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: BlocBuilder<TextToSpeechSettingsCubit, TextToSpeechSettingsState>(
        builder: (context, state) {
          final voiceLabel = state.voiceLocale == null
              ? 'System default'
              : '${state.voiceLocale} · ${state.voiceName}';
          final selectedEngine = _engines.contains(state.engine)
              ? state.engine
              : null;
          final llamaDartCubit = widget.llamaDartCubit;

          return Card(
            elevation: 0,
            child: ExpansionTile(
              shape: Border.fromBorderSide(BorderSide.none),
              initiallyExpanded: widget.initiallyExpanded,
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text(
                'Voice output (TTS)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Android native voice or local LlamaDart neural voice',
                style: TextStyle(fontSize: 13),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<TextToSpeechBackend>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: TextToSpeechBackend.native,
                        icon: Icon(Icons.phone_android_rounded),
                        label: Text('Android'),
                      ),
                      ButtonSegment(
                        value: TextToSpeechBackend.llamaDart,
                        icon: Icon(Icons.memory_rounded),
                        label: Text('Local AI'),
                      ),
                    ],
                    selected: {state.backend},
                    onSelectionChanged: (selection) =>
                        _selectBackend(selection.first),
                  ),
                ),
                const SizedBox(height: 12),
                if (state.backend == TextToSpeechBackend.llamaDart &&
                    llamaDartCubit != null)
                  _LlamaDartTtsModelPanel(
                    cubit: llamaDartCubit,
                    previewing: _previewing,
                    onPreview: _preview,
                    onAddExternal: _addExternalTtsModel,
                  )
                else if (_loading)
                  const LinearProgressIndicator(minHeight: 2)
                else ...[
                  if (_engines.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedEngine,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'TTS engine',
                        prefixIcon: Icon(Icons.memory_outlined),
                      ),
                      items: [
                        for (final engine in _engines)
                          DropdownMenuItem(value: engine, child: Text(engine)),
                      ],
                      onChanged: _selectEngine,
                    ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('Voice model'),
                    subtitle: Text(
                      voiceLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: _voices.isNotEmpty,
                    onTap: () => _showVoicePicker(state),
                  ),
                  _SettingSlider(
                    label: 'Speed',
                    value: state.speechRate,
                    min: 0.2,
                    max: 0.9,
                    onChanged: widget.cubit.setSpeechRate,
                    onChangeEnd: (_) => _apply(),
                  ),
                  _SettingSlider(
                    label: 'Pitch',
                    value: state.pitch,
                    min: 0.5,
                    max: 1.5,
                    onChanged: widget.cubit.setPitch,
                    onChangeEnd: (_) => _apply(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _previewing ? null : _preview,
                      icon: _previewing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 1),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text('Preview voice'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LlamaDartTtsModelPanel extends StatelessWidget {
  const _LlamaDartTtsModelPanel({
    required this.cubit,
    required this.previewing,
    required this.onPreview,
    required this.onAddExternal,
  });

  final LlamaDartTtsModelCubit cubit;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onAddExternal;

  Future<void> _selectProfile(
    BuildContext context,
    LlamaDartTtsModelProfile profile,
  ) async {
    if (profile == cubit.state.profile) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Use ${profile.name}?'),
        content: const Text(
          'The current local AI runtime will be released, then this voice '
          'model will be preloaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Use model'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.selectProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LlamaDartTtsModelCubit, LlamaDartTtsModelState>(
      bloc: cubit,
      builder: (context, state) {
        final downloading =
            state.phase == LlamaDartTtsModelPhase.downloading ||
            state.phase == LlamaDartTtsModelPhase.verifying;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final profile in state.allProfiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !state.isBusy,
                onTap: () => _selectProfile(context, profile),
                leading: Icon(
                  state.profile == profile
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: state.profile == profile
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${profile.isExternal ? 'Custom GGUF pair' : 'French + 9 languages'} · ${_formatSize(profile.totalSizeBytes)}\n'
                  'Experimental on 4 GB · ${profile.minimumRamGb} GB RAM recommended',
                ),
                isThreeLine: true,
                trailing:
                    state.profile == profile &&
                        state.phase == LlamaDartTtsModelPhase.ready
                    ? const Chip(label: Text('Ready'))
                    : profile.isExternal
                    ? IconButton(
                        tooltip: 'Remove from list',
                        onPressed: state.isBusy
                            ? null
                            : () => cubit.removeCustom(profile.id),
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: state.isBusy ? null : onAddExternal,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Add Qwen3-TTS GGUF pair'),
              ),
            ),
            if (state.isBusy || downloading) ...[
              LinearProgressIndicator(
                value: state.phase == LlamaDartTtsModelPhase.downloading
                    ? state.progress
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                state.phase == LlamaDartTtsModelPhase.downloading
                    ? '${(state.progress * 100).round()}% · ${state.message ?? 'Downloading'}'
                    : state.message ?? 'Preparing…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (state.message != null)
              Text(
                state.message!,
                style: TextStyle(
                  color: state.phase == LlamaDartTtsModelPhase.failed
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (downloading)
                  TextButton(
                    onPressed: cubit.cancel,
                    child: const Text('Cancel'),
                  )
                else if (state.installed) ...[
                  TextButton(
                    onPressed: state.isBusy ? null : cubit.remove,
                    child: Text(
                      state.profile.isExternal
                          ? 'Remove from list'
                          : 'Remove download',
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: previewing ? null : onPreview,
                    icon: previewing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 1),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Preview'),
                  ),
                ] else if (!state.profile.isExternal)
                  FilledButton.tonalIcon(
                    onPressed: state.isBusy ? null : cubit.install,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Install model'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatSize(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    return gb >= 1
        ? '${gb.toStringAsFixed(1)} GB'
        : '${(bytes / (1024 * 1024)).round()} MB';
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 54, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 14,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
