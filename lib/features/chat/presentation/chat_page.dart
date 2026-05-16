import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/providers/download_notifier.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_list.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/chat/presentation/chat_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChat = ref.watch(selectedChatIdProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloadState = ref.watch(downloadProvider);

    final body = selectedChat == null
        ? const Center(child: Text('Select or create a chat'))
        : activeGemmaChat.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (session) {
              if (session == null) {
                return const Center(child: Text('No active model'));
              }
              return ChatView(chatId: selectedChat, chat: session.chat);
            },
          );

    return Scaffold(
      appBar: const ChatAppBar(),
      drawer: const ChatDrawer(),
      bottomNavigationBar: activeGemmaChat.maybeWhen(
        data: (session) => selectedChat == null || session == null
            ? const SizedBox.shrink()
            : AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(child: const ChatInput()),
              ),
        orElse: () => const SizedBox.shrink(),
      ),
      body: Stack(
        children: [
          Column(children: [Expanded(child: body)]),
          if (activeInstall != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Installing ${activeInstall.label}...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (downloadState[activeInstall.key] == null)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 4,))
                        else
                          LinearProgressIndicator(
                            value: downloadState[activeInstall.key],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final modelLabel = activeGemmaChat.maybeWhen(
      data: (session) => session?.chat.modelType.name ?? 'Model not loaded',
      orElse: () => 'Model loading...',
    );
    final modelColor = activeGemmaChat.maybeWhen(
      data: (session) => session == null ? Colors.red : null,
      orElse: () => null,
    );

    return AppBar(
      scrolledUnderElevation: 2,
      elevation: 2,
      title: TextButton(
        onPressed: () => _showModelSelector(context, ref),
        child: Column(
          children: [
            const Text(
              'Gena',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).highlightColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                modelLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: modelColor),
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.squarePen500, size: 20),
          onPressed: () {
            unawaited(
              ref.read(selectedChatIdProvider.notifier).createNewThread(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.pushNamed('model-setting'),
        ),
      ],
    );
  }

  Future<void> _showModelSelector(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Consumer(
            builder: (context, sheetRef, _) {
              final modelsAsync = sheetRef.watch(modelRepositoryProvider);
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
                          await ref
                              .read(downloadProvider.notifier)
                              .installModel(model);
                          ref.invalidate(activeGemmaChatProvider);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 4,))),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: const Text(
                      'History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(selectedChatIdProvider.notifier)
                            .createNewThread(),
                      );
                      context.pop(context);
                    },
                    icon: const Icon(LucideIcons.squarePen500, size: 20),
                  ),
                ],
              ),
            ),

            const Divider(),
            const Expanded(child: ChatHistoryList()),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.cpu),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('download');
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.settings),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('setting');
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
