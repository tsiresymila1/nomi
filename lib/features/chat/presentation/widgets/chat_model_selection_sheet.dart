import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/downloads/data/model_repository.dart';

class ChatModelSelectionSheet extends ConsumerWidget {
  const ChatModelSelectionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelRepositoryProvider);
    return modelsAsync.when(
      data: (models) {
        if (models.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No models. Add one from Download page.'),
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
                Future.microtask(() =>ref.read(chatPageActionsProvider).installModel(model));
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
