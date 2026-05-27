import 'package:flutter/material.dart';

class ModelCapabilitySwitches extends StatelessWidget {
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final ValueChanged<bool> onSupportImageChanged;
  final ValueChanged<bool> onSupportAudioChanged;
  final ValueChanged<bool> onFunctionCallsChanged;
  final ValueChanged<bool> onIsThinkingChanged;

  const ModelCapabilitySwitches({
    super.key,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.isThinking,
    required this.onSupportImageChanged,
    required this.onSupportAudioChanged,
    required this.onFunctionCallsChanged,
    required this.onIsThinkingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: supportImage,
                title: const Text('Support image'),
                onChanged: onSupportImageChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: supportAudio,
                title: const Text('Support audio'),
                onChanged: onSupportAudioChanged,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: supportsFunctionCalls,
                title: const Text('Function calls'),
                onChanged: onFunctionCallsChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isThinking,
                title: const Text('Thinking default'),
                onChanged: onIsThinkingChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
