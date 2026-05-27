import 'package:flutter/material.dart';

class ModelSettingsSliderTile extends StatelessWidget {
  final String label;
  final String valueText;
  final Widget slider;

  const ModelSettingsSliderTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              valueText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}
