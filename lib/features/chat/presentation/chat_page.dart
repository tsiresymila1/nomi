import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:gena/features/chat/presentation/widgets/chat_drawer.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';
import 'package:gena/features/chat/presentation/widgets/chat_view.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChat = ref.watch(selectedChatIdProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloadState = ref.watch(downloadProvider);

    final body = isSwitchingModel
        ?   Center(child: SpinKitThreeInOut(size: 40,color: Theme.of(context).colorScheme.primary,))
        : selectedChat == null
        ? const Center(child: Text('Select or create a chat'))
        : activeGemmaChat.when(
            loading: () =>  Center(child: SpinKitThreeInOut(size: 40,color: Theme.of(context).colorScheme.primary,)),
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
        data: (session) =>
            isSwitchingModel || selectedChat == null || session == null
            ? const SizedBox.shrink()
            : AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: const SafeArea(child: ChatInput()),
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
                          Center(child: SpinKitThreeInOut(size: 40,color: Theme.of(context).colorScheme.primary,))
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
