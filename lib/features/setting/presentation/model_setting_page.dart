import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_number_field.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_slider_tile.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:gena/features/setting/data/providers/chat_model_settings_provider.dart';

class ModelSettingsPage extends ConsumerStatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  ConsumerState<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends ConsumerState<ModelSettingsPage> {
  final _systemPromptController = TextEditingController();
  final _topKController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _tokenBufferController = TextEditingController();
  final _randomSeedController = TextEditingController();

  bool _hydratedFromStore = false;
  bool _hasEditedForm = false;
  bool _isSaving = false;
  bool _isResettingGemma = false;

  double _temperature = 0.8;
  double _topP = 0.95;
  String _preferredBackend = 'gpu';
  bool _useModelThinkingDefault = true;
  bool _isThinkingOverride = false;

  TextTheme _font14TextTheme(TextTheme source) {
    TextStyle? normalize(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(fontSize: 14);
    }

    return source.copyWith(
      displayLarge: normalize(source.displayLarge),
      displayMedium: normalize(source.displayMedium),
      displaySmall: normalize(source.displaySmall),
      headlineLarge: normalize(source.headlineLarge),
      headlineMedium: normalize(source.headlineMedium),
      headlineSmall: normalize(source.headlineSmall),
      titleLarge: normalize(source.titleLarge),
      titleMedium: normalize(source.titleMedium),
      titleSmall: normalize(source.titleSmall),
      bodyLarge: normalize(source.bodyLarge),
      bodyMedium: normalize(source.bodyMedium),
      bodySmall: normalize(source.bodySmall),
      labelLarge: normalize(source.labelLarge),
      labelMedium: normalize(source.labelMedium),
      labelSmall: normalize(source.labelSmall),
    );
  }

  @override
  void initState() {
    super.initState();
    _systemPromptController.addListener(_markEdited);
    _topKController.addListener(_markEdited);
    _maxTokensController.addListener(_markEdited);
    _tokenBufferController.addListener(_markEdited);
    _randomSeedController.addListener(_markEdited);
  }

  @override
  void dispose() {
    _systemPromptController.removeListener(_markEdited);
    _topKController.removeListener(_markEdited);
    _maxTokensController.removeListener(_markEdited);
    _tokenBufferController.removeListener(_markEdited);
    _randomSeedController.removeListener(_markEdited);

    _systemPromptController.dispose();
    _topKController.dispose();
    _maxTokensController.dispose();
    _tokenBufferController.dispose();
    _randomSeedController.dispose();
    super.dispose();
  }

  void _markEdited() {
    _hasEditedForm = true;
  }

  void _loadSettingsIntoForm(ChatModelSettings settings) {
    _systemPromptController.text = settings.systemPrompt;
    _topKController.text = settings.topK.toString();
    _maxTokensController.text = settings.maxTokens.toString();
    _tokenBufferController.text = settings.tokenBuffer.toString();
    _randomSeedController.text = settings.randomSeed.toString();

    _temperature = settings.temperature;
    _topP = settings.topP;
    _preferredBackend = settings.preferredBackend;
    final override = settings.isThinkingOverride;
    _useModelThinkingDefault = override == null;
    _isThinkingOverride = override ?? false;
  }

  Future _saveSettings() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(modelSettingsActionsProvider)
          .save(
            ModelSettingsSaveInput(
              systemPrompt: _systemPromptController.text,
              topKText: _topKController.text,
              maxTokensText: _maxTokensController.text,
              tokenBufferText: _tokenBufferController.text,
              randomSeedText: _randomSeedController.text,
              temperature: _temperature,
              topP: _topP,
              preferredBackend: _preferredBackend,
              isThinkingOverride: _useModelThinkingDefault
                  ? null
                  : _isThinkingOverride,
            ),
          );

      _hasEditedForm = false;
      _showToast('Model settings saved', AppToastType.success);
    } on ModelSettingsValidationException catch (e) {
      _showToast(e.message, AppToastType.error);
    } catch (e) {
      _showToast('Save failed: $e', AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetModelSettings() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final defaults = await ref
          .read(modelSettingsActionsProvider)
          .resetDefaults();
      _loadSettingsIntoForm(defaults);
      _hasEditedForm = false;
      if (!mounted) return;
      setState(() {});
      _showToast('Model settings reset to defaults', AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      _showToast('Reset failed: $e', AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetFlutterGemma() async {
    if (_isResettingGemma) return;

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset FlutterGemma'),
        content: const Text(
          'This clears active model state. Installed files stay on disk. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    setState(() => _isResettingGemma = true);
    try {
      ref.read(modelSettingsActionsProvider).resetFlutterGemma();
      if (!mounted) return;
      _showToast('FlutterGemma reset complete', AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      _showToast('Reset failed: $e', AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _isResettingGemma = false);
      }
    }
  }

  void _showToast(String text, AppToastType type) {
    AppToast.show(text, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(chatModelSettingsProvider);
    ref.listen<ChatModelSettings>(chatModelSettingsProvider, (_, next) {
      if (!_hasEditedForm && mounted) {
        setState(() {
          _loadSettingsIntoForm(next);
        });
      }
    });

    if (!_hydratedFromStore) {
      _hydratedFromStore = true;
      _loadSettingsIntoForm(settings);
      _hasEditedForm = false;
    }

    Widget animatedItem(int index, Widget child) {
      final delay = (index * 20).ms;
      return child
          .animate(key: ValueKey('model-setting-item-$index'))
          .fade(duration: 500.ms, delay: delay)
          .scale(
            delay: delay + 120.ms,
            duration: 260.ms,
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            curve: Curves.easeOutCubic,
          );
    }

    final baseTheme = Theme.of(context);
    final textTheme14 = _font14TextTheme(baseTheme.textTheme);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: textTheme14,
        primaryTextTheme: _font14TextTheme(baseTheme.primaryTextTheme),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          hintStyle: const TextStyle(fontSize: 14),
          labelStyle: const TextStyle(fontSize: 14),
          helperStyle: const TextStyle(fontSize: 14),
          errorStyle: const TextStyle(fontSize: 14),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Model Settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                animatedItem(
                  0,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      const Text(
                        'General prompt',
                        style: TextStyle(fontSize: 14),
                      ),
                      TextField(
                        controller: _systemPromptController,
                        minLines: 5,
                        maxLines: 10,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'You are helpfully assistant',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                animatedItem(1, const SizedBox(height: 16)),
                animatedItem(
                  2,
                  ModelSettingsSliderTile(
                    label: 'Temperature',
                    valueText: _temperature.toStringAsFixed(2),
                    slider: Slider(
                      value: _temperature,
                      min: 0,
                      max: 2,
                      divisions: 40,
                      onChanged: (value) => setState(() {
                        _temperature = value;
                        _hasEditedForm = true;
                      }),
                    ),
                  ),
                ),
                animatedItem(
                  3,
                  ModelSettingsSliderTile(
                    label: 'Top-P',
                    valueText: _topP.toStringAsFixed(2),
                    slider: Slider(
                      value: _topP,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      onChanged: (value) => setState(() {
                        _topP = value;
                        _hasEditedForm = true;
                      }),
                    ),
                  ),
                ),
                animatedItem(4, const SizedBox(height: 8)),
                animatedItem(
                  5,
                  Row(
                    children: [
                      Expanded(
                        child: ModelSettingsNumberField(
                          controller: _topKController,
                          label: 'Top-K',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ModelSettingsNumberField(
                          controller: _maxTokensController,
                          label: 'Max tokens',
                        ),
                      ),
                    ],
                  ),
                ),
                animatedItem(6, const SizedBox(height: 12)),
                animatedItem(
                  7,
                  Row(
                    children: [
                      Expanded(
                        child: ModelSettingsNumberField(
                          controller: _tokenBufferController,
                          label: 'Token buffer',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ModelSettingsNumberField(
                          controller: _randomSeedController,
                          label: 'Random seed',
                        ),
                      ),
                    ],
                  ),
                ),
                animatedItem(8, const SizedBox(height: 16)),
                animatedItem(
                  9,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      const Text('Preferred backend'),
                      DropdownButtonFormField<String>(
                        initialValue: _preferredBackend,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'auto', child: Text('Auto')),
                          DropdownMenuItem(value: 'gpu', child: Text('GPU')),
                          DropdownMenuItem(value: 'cpu', child: Text('CPU')),
                          DropdownMenuItem(value: 'npu', child: Text('NPU')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _preferredBackend = value;
                            _hasEditedForm = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                animatedItem(
                  10,
                  SwitchListTile(
                    value: _useModelThinkingDefault,
                    onChanged: (value) => setState(() {
                      _useModelThinkingDefault = value;
                      _hasEditedForm = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use model default thinking'),
                    subtitle: const Text(
                      'When enabled, use model capability from model info.',
                    ),
                  ),
                ),
                if (!_useModelThinkingDefault)
                  animatedItem(
                    11,
                    SwitchListTile(
                      value: _isThinkingOverride,
                      onChanged: (value) => setState(() {
                        _isThinkingOverride = value;
                        _hasEditedForm = true;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable thinking mode'),
                      subtitle: const Text(
                        'Override model default for reasoning/thinking behavior.',
                      ),
                    ),
                  ),
                animatedItem(12, const SizedBox(height: 12)),
                animatedItem(
                  13,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _resetModelSettings,
                          child: const Text('Reset Default'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving
                              ? null
                              : () => unawaited(_saveSettings()),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                animatedItem(14, const SizedBox(height: 24)),
                animatedItem(15, const Divider()),
                animatedItem(16, const SizedBox(height: 12)),
                animatedItem(
                  17,
                  FilledButton.icon(
                    onPressed: _isResettingGemma ? null : _resetFlutterGemma,
                    icon: _isResettingGemma
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restart_alt),
                    label: const Text('Reset FlutterGemma'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
