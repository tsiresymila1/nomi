import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/setting/presentation/cubit/text_to_speech_settings_cubit.dart';

class TextToSpeechSettingsSection extends StatefulWidget {
  const TextToSpeechSettingsSection({
    super.key,
    required this.cubit,
    required this.textToSpeech,
  });

  final TextToSpeechSettingsCubit cubit;
  final FlutterTextToSpeech textToSpeech;

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
                      title: Text(voice.locale),
                      subtitle: Text(
                        '${voice.name}\n${voice.quality} quality · ${voice.latency} latency',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: recommended
                          ? const Chip(label: Text('Recommended'))
                          : isSelected
                          ? const Icon(Icons.check_rounded)
                          : null,
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
    if (selected == null) return;
    widget.cubit.selectVoice(selected);
    await _apply();
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      await _apply();
      await widget.textToSpeech.speak(
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

          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text(
                'Voice output (TTS)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Android engine, voice and speaking style',
                style: TextStyle(fontSize: 13),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                if (_loading)
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
