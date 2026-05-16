import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    final selectedChat = ref.watch(selectedChatIdProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloadState = ref.watch(downloadProvider);

    final body = isSwitchingModel
        ? reveal(
            Center(
              child: SpinKitThreeInOut(
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : selectedChat == null
        ? reveal(const Center(child: Text('Select or create a chat')))
        : activeGemmaChat.when(
            loading: () => reveal(
              Center(
                child: SpinKitThreeInOut(
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            error: (error, stack) =>
                reveal(Center(child: Text('Error: $error'))),
            data: (session) {
              if (session == null) {
                return reveal(const Center(child: Text('No active model')));
              }
              return ChatView(chatId: selectedChat, chat: session.chat);
            },
          );

    final bottomBar = activeGemmaChat.maybeWhen(
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
    );

    return Scaffold(
      appBar: const ChatAppBar(),
      drawer: const ChatDrawer(),
      bottomNavigationBar: bottomBar is SizedBox
          ? bottomBar
          : reveal(bottomBar, delayMs: 60),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${isSwitchingModel}_${selectedChat ?? "none"}_${activeInstall?.key ?? "idle"}',
                    ),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
          if (activeInstall != null)
            reveal(
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
                            SpinKitThreeInOut(
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            )
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
            ),
        ],
      ),
    );
  }
}
