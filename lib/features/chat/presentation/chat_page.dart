import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:gena/features/chat/presentation/widgets/chat_drawer.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';
import 'package:gena/features/chat/presentation/widgets/chat_view.dart';
import 'package:gena/features/chat/presentation/widgets/native_action_call_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _isNativeSheetOpen = false;
  String? _lastNativeRequestId;

  Future<void> _showNativeActionSheet(
    BuildContext context,
    NativeToolRequest request,
  ) async {
    if (_isNativeSheetOpen || _lastNativeRequestId == request.id) return;
    _isNativeSheetOpen = true;
    _lastNativeRequestId = request.id;

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return NativeActionCallSheet(request: request);
      },
    );

    if (!mounted) return;
    if (approved == true) {
      ref.read(nativeToolExecutionProvider.notifier).approveCurrent();
    } else {
      ref.read(nativeToolExecutionProvider.notifier).rejectCurrent();
    }
    _isNativeSheetOpen = false;
    _lastNativeRequestId = null;
  }

  bool _hasSessionConfigChange(ModelInfo previous, ModelInfo next) {
    return previous.provider != next.provider ||
        previous.modelType != next.modelType ||
        previous.supportImage != next.supportImage ||
        previous.supportAudio != next.supportAudio ||
        previous.supportsFunctionCalls != next.supportsFunctionCalls ||
        previous.isThinking != next.isThinking ||
        previous.temperature != next.temperature ||
        previous.topK != next.topK ||
        previous.topP != next.topP ||
        previous.maxTokens != next.maxTokens ||
        previous.tokenBuffer != next.tokenBuffer ||
        previous.randomSeed != next.randomSeed ||
        previous.preferredBackend != next.preferredBackend ||
        previous.sourceType != next.sourceType ||
        previous.source != next.source ||
        previous.modelId != next.modelId ||
        previous.apiUrl != next.apiUrl ||
        previous.apiToken != next.apiToken;
  }


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

  @override
  Widget build(BuildContext context) {
    final selectedChat = ref.watch(selectedChatIdProvider);
    final activeModel = ref.watch(activeModelInfoProvider);
    final activeRuntime = ref.watch(activeGemmaModelRuntimeProvider);
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final themeMode = ref.watch(themeModeProvider);

    final coloScheme = Theme.of(context).colorScheme;
    final isDark = themeMode == ThemeMode.dark;
    final gradColor = isDark ? Colors.black : Colors.white70;

    final usesLocalRuntime = activeModel?.provider == 'local';
    final hasActiveRuntimeValue = activeRuntime.hasValue;
    final isModelLoading =
        isSwitchingModel ||
        (usesLocalRuntime &&
            (activeRuntime.isLoading && !hasActiveRuntimeValue));

    final body = selectedChat == null
        ? reveal(const Center(child: Text('Select or create a chat')))
        : activeModel == null
        ? reveal(const Center(child: Text('No active model')))
        : ChatView(
            chatId: selectedChat,
          ).animate().fadeIn(duration: Duration(milliseconds: 1200));

    final canShowInput =
        !isSwitchingModel && selectedChat != null && activeModel != null;

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

    // listener for tool call
    ref.listen<NativeToolExecutionState>(nativeToolExecutionProvider, (
        previous,
        next,
        ) {
      final request = next.currentRequest;
      if (request == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNativeActionSheet(context, request);
      });
    });
    // listen for workspace config change
    ref.listen<ModelInfo?>(activeModelInfoProvider, (previous, next) {
      if (previous == null || next == null) return;
      if (previous.id != next.id) return;

      if (!_hasSessionConfigChange(previous, next)) return;

      logger.i(
        'Active model config changed for id=${next.id} (${next.name}). Reloading runtime/chat session.',
      );
      ref.invalidate(activeGemmaModelRuntimeProvider);
      ref.invalidate(activeGemmaChatProvider);
    });

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
                      '${isSwitchingModel}_${selectedChat ?? "none"}_${activeModel?.id ?? "nomodel"}',
                    ),
                    child: Visibility(
                      visible:
                          isModelLoading &&
                          selectedChat != null &&
                          activeModel != null,
                      replacement: body,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 12,
                              child: SpinKitThreeBounce(
                                size: 10,
                                color: coloScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isModelLoading
                                  ? 'Loading model...'
                                  : 'No active chat',
                              style: TextStyle(fontSize: 12),
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
        ],
      ),
    );
  }
}
