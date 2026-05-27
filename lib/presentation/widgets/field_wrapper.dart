import 'package:flutter/material.dart';

class FieldWrapper extends StatelessWidget {
  final String? label;
  final Widget field;
  const FieldWrapper({super.key, this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          ),
          const SizedBox(height: 4),
        ],
        field,
      ],
    );
  }
}
