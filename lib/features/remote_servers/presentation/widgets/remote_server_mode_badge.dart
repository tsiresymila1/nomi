import 'package:flutter/material.dart';

class RemoteServerModeBadge extends StatelessWidget {
  const RemoteServerModeBadge({required this.auto, super.key});

  final bool auto;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = auto ? 'Auto' : 'Manual';
    final bg = auto
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
