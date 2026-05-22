import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:gena/features/chat/presentation/widgets/chat_drawer.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';
import 'package:gena/features/chat/presentation/widgets/chat_view.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _isNativeDialogOpen = false;
  String? _lastNativeRequestId;

  Future<void> _showNativeActionDialog(
    BuildContext context,
    NativeToolRequest request,
  ) async {
    if (_isNativeDialogOpen || _lastNativeRequestId == request.id) return;
    _isNativeDialogOpen = true;
    _lastNativeRequestId = request.id;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Native Action'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The assistant requests action: ${_toolLabel(request.toolName)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  request.args.isEmpty
                      ? 'No arguments'
                      : ref
                            .read(nativeToolActionsProvider)
                            .formatArgsForDisplay(request.args),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (approved == true) {
      ref.read(nativeToolExecutionProvider.notifier).approveCurrent();
    } else {
      ref.read(nativeToolExecutionProvider.notifier).rejectCurrent();
    }
    _isNativeDialogOpen = false;
    _lastNativeRequestId = null;
  }

  String _toolLabel(String toolName) {
    return switch (toolName) {
      nativeOpenUrlToolName => 'Open URL',
      nativeOpenAppToolName => 'Open App',
      nativeSendEmailToolName => 'Send Email',
      nativeFlashlightToolName => 'Flashlight',
      _ => toolName,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NativeToolExecutionState>(nativeToolExecutionProvider, (
      previous,
      next,
    ) {
      final request = next.currentRequest;
      if (request == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNativeActionDialog(context, request);
      });
    });

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
    final activeModel = ref.watch(activeModelInfoProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final activeRuntime = ref.watch(activeGemmaModelRuntimeProvider);
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloadState = ref.watch(downloadProvider);
    final themeMode = ref.watch(themeModeProvider);

    final coloScheme = Theme.of(context).colorScheme;
    final isDark = themeMode == ThemeMode.dark;
    final gradColor = isDark ? Colors.black : Colors.white70;

    final usesLocalRuntime = activeModel?.provider == 'local';
    final isModelLoading =
        isSwitchingModel ||
        activeInstall != null ||
        (usesLocalRuntime &&
            (activeRuntime.isLoading || activeGemmaChat.isLoading));

    final body = isModelLoading
        ? reveal(
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  SpinKitThreeBounce(size: 25, color: coloScheme.primary),
                  Text("Wait a minutes. Loading model ..."),
                ],
              ),
            ),
          )
        : selectedChat == null
        ? reveal(const Center(child: Text('Select or create a chat')))
        : activeModel == null
        ? reveal(const Center(child: Text('No active model')))
        : usesLocalRuntime
        ? activeGemmaChat.when(
            loading: () => reveal(
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    SpinKitThreeBounce(size: 25, color: coloScheme.primary),
                    Text("Wait a minutes. Loading model ..."),
                  ],
                ),
              ),
            ),
            error: (error, stack) =>
                reveal(Center(child: Text('Error: $error'))),
            data: (session) {
              if (session == null) {
                return reveal(const Center(child: Text('No active model')));
              }
              return ChatView(
                chatId: selectedChat,
              ).animate().fadeIn(duration: Duration(milliseconds: 1200));
            },
          )
        : ChatView(
            chatId: selectedChat,
          ).animate().fadeIn(duration: Duration(milliseconds: 1200));

    final canShowInput =
        !isSwitchingModel &&
        selectedChat != null &&
        activeModel != null &&
        (!usesLocalRuntime ||
            activeGemmaChat.maybeWhen(
              data: (session) => session != null,
              orElse: () => false,
            ));

    final bottomBar = !canShowInput
        ? const SizedBox.shrink()
        : AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: const SafeArea(child: ChatInput()),
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: ChatAppBar(gradColor: gradColor),
      drawer: const ChatDrawer(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradColor.withAlpha(0),
              gradColor.withAlpha(125),
              gradColor.withAlpha(250),
            ],
          ),
        ),
        child: bottomBar is SizedBox
            ? bottomBar
            : reveal(bottomBar, delayMs: 60),
      ),
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
                      '${isSwitchingModel}_${selectedChat ?? "none"}_${activeInstall?.key ?? "idle"}_${activeModel?.id ?? "nomodel"}',
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
                            SpinKitThreeBounce(
                              size: 30,
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
