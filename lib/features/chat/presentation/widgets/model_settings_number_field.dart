import 'package:flutter/material.dart';

class ModelSettingsNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const ModelSettingsNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
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
}
