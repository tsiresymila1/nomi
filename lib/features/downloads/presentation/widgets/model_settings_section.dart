import 'package:flutter/material.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_slider_tile.dart';

class ModelSettingsSection extends StatelessWidget {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final int tokenBuffer;
  final int randomSeed;
  final String providerType;
  final int tokenBufferMax;
  final int tokenBufferMin;
  final TextEditingController maxTokensController;
  final TextEditingController outputTokensController;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onTopPChanged;
  final ValueChanged<int> onTopKChanged;
  final ValueChanged<int> onMaxTokensChanged;
  final ValueChanged<int> onTokenBufferChanged;
  final ValueChanged<int> onRandomSeedChanged;

  const ModelSettingsSection({
    super.key,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxTokens,
    required this.tokenBuffer,
    required this.randomSeed,
    required this.providerType,
    required this.tokenBufferMax,
    required this.tokenBufferMin,
    required this.maxTokensController,
    required this.outputTokensController,
    required this.onTemperatureChanged,
    required this.onTopPChanged,
    required this.onTopKChanged,
    required this.onMaxTokensChanged,
    required this.onTokenBufferChanged,
    required this.onRandomSeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModelSettingsSliderTile(
          label: 'Temperature',
          valueText: temperature.toStringAsFixed(2),
          slider: Slider(
            padding: EdgeInsets.symmetric(vertical: 12),
            value: temperature,
            min: 0,
            max: 2,
            divisions: 40,
            onChanged: onTemperatureChanged,
          ),
        ),
        ModelSettingsSliderTile(
          label: 'Top-P',
          valueText: topP.toStringAsFixed(2),
          slider: Slider(
            padding: EdgeInsets.symmetric(vertical: 12),
            value: topP,
            min: 0.1,
            max: 1,
            divisions: 18,
            onChanged: onTopPChanged,
          ),
        ),
        const SizedBox(height: 8),
        ModelSettingsSliderTile(
          label: 'Top-K',
          valueText: topK.toString(),
          slider: Slider(
            padding: EdgeInsets.symmetric(vertical: 12),
            value: topK.toDouble(),
            min: 1,
            max: 200,
            divisions: 199,
            onChanged: (value) => onTopKChanged(value.round()),
          ),
        ),
        if (providerType == 'local')
          ModelSettingsSliderTile(
            label: 'Max tokens',
            valueText: maxTokens.toString(),
            slider: Slider(
              padding: EdgeInsets.symmetric(vertical: 12),
              value: maxTokens.toDouble(),
              min: 256,
              max: 8192,
              divisions: 248,
              onChanged: (value) => onMaxTokensChanged(value.round()),
            ),
          ),
        if (providerType == 'local')
          ModelSettingsSliderTile(
            label: 'Output tokens',
            valueText: tokenBuffer.toString(),
            slider: Slider(
              padding: EdgeInsets.symmetric(vertical: 8),
              value: tokenBuffer.toDouble(),
              min: tokenBufferMin.toDouble(),
              max: tokenBufferMax.toDouble(),
              divisions: tokenBufferMax > tokenBufferMin
                  ? tokenBufferMax - tokenBufferMin
                  : 1,
              onChanged: (value) => onTokenBufferChanged(value.round()),
            ),
          ),
        ModelSettingsSliderTile(
          label: 'Random seed',
          valueText: randomSeed.toString(),
          slider: Slider(
            padding: EdgeInsets.symmetric(vertical: 12),
            value: randomSeed.toDouble(),
            min: 0,
            max: 10000,
            divisions: 10000,
            onChanged: (value) => onRandomSeedChanged(value.round()),
          ),
        ),
      ],
    );
  }
}
