import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:gena/features/setting/data/chat_model_settings_provider.dart';

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
  bool _isThinking = false;

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
    _isThinking = settings.isThinking;
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    final topK = int.tryParse(_topKController.text.trim());
    final maxTokens = int.tryParse(_maxTokensController.text.trim());
    final tokenBuffer = int.tryParse(_tokenBufferController.text.trim());
    final randomSeed = int.tryParse(_randomSeedController.text.trim());

    if (topK == null || topK < 1 || topK > 200) {
      _showSnack('Top-K must be between 1 and 200');
      return;
    }
    if (maxTokens == null || maxTokens < 256 || maxTokens > 8192) {
      _showSnack('Max tokens must be between 256 and 8192');
      return;
    }
    if (tokenBuffer == null || tokenBuffer < 32 || tokenBuffer > 4096) {
      _showSnack('Token buffer must be between 32 and 4096');
      return;
    }
    if (randomSeed == null || randomSeed < 0) {
      _showSnack('Random seed must be 0 or greater');
      return;
    }
    if (tokenBuffer >= maxTokens) {
      _showSnack('Token buffer must be smaller than max tokens');
      return;
    }

    final next = ChatModelSettings(
      systemPrompt: _systemPromptController.text.trim(),
      temperature: _temperature,
      topK: topK,
      topP: _topP,
      maxTokens: maxTokens,
      tokenBuffer: tokenBuffer,
      randomSeed: randomSeed,
      preferredBackend: _preferredBackend,
      isThinking: _isThinking,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(chatModelSettingsProvider.notifier).save(next);
      _hasEditedForm = false;
      ref.invalidate(activeGemmaChatProvider);
      if (!mounted) return;
      _showSnack('Model settings saved');
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
      await ref.read(chatModelSettingsProvider.notifier).resetDefaults();
      final defaults = ChatModelSettings.defaults();
      _loadSettingsIntoForm(defaults);
      _hasEditedForm = false;
      ref.invalidate(activeGemmaChatProvider);
      if (!mounted) return;
      setState(() {});
      _showSnack('Model settings reset to defaults');
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
      FlutterGemma.reset();
      ref.invalidate(activeGemmaChatProvider);
      if (!mounted) return;
      _showSnack('FlutterGemma reset complete');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Reset failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isResettingGemma = false);
      }
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

    return Scaffold(
      appBar: AppBar(elevation:2, scrolledUnderElevation:2,title: const Text('Model Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [

              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text("General prompt", style: TextStyle(fontSize: 14),),
                  TextField(
                    controller: _systemPromptController,
                    minLines: 5,
                    maxLines: 10,
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'You are helpfully assistant',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sliderTile(
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
              _sliderTile(
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _topKController,
                      label: 'Top-K',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      controller: _maxTokensController,
                      label: 'Max tokens',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _tokenBufferController,
                      label: 'Token buffer',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      controller: _randomSeedController,
                      label: 'Random seed',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text("Preferred backend"),
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
              SwitchListTile(
                value: _isThinking,
                onChanged: (value) => setState(() {
                  _isThinking = value;
                  _hasEditedForm = true;
                }),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable thinking mode'),
                subtitle: const Text('Use reasoning/thinking mode when supported'),
              ),
              const SizedBox(height: 12),
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
                      onPressed: _isSaving ? null : _saveSettings,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(label, style: TextStyle(fontSize: 14)),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _sliderTile({
    required String label,
    required String valueText,
    required Widget slider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(
              valueText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}
