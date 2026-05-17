import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/downloads/data/model_repository.dart';

class ChatModelSelectionSheet extends ConsumerWidget {
  const ChatModelSelectionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget reveal(Widget child, {int delayMs = 0}) {
      return child
          .animate()
          .fade(duration: 500.ms, delay: delayMs.ms)
          .scale(
            delay: (delayMs + 120).ms,
            duration: 260.ms,
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            curve: Curves.easeOutCubic,
          );
    }

    final modelsAsync = ref.watch(modelRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            "Models",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          modelsAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return reveal(
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No models. Add one from Download page.'),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  return ListTile(
                        title: Text(model.name),
                        subtitle: Text(model.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Navigator.of(context).pop();
                          unawaited(
                            ref
                                .read(chatPageActionsProvider)
                                .installModel(model),
                          );
                        },
                      )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 30).ms)
                      .slideY(begin: 0.06, end: 0);
                },
              );
            },
            loading: () => reveal(
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
              ),
            ),
            error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
          ),
        ],
      ),
    );
  }
}
