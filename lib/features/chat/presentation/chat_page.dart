import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:gena/features/chat/presentation/widgets/chat_drawer.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';
import 'package:gena/features/chat/presentation/widgets/chat_view.dart';
import 'package:gena/features/chat/presentation/widgets/native_action_call_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return NativeActionCallSheet(request: request);
      },
    );

    if (!mounted) return;
    if (approved == true) {
      sl<NativeToolExecutionCubit>().approveCurrent();
    } else {
      sl<NativeToolExecutionCubit>().rejectCurrent();
    }
    _isNativeSheetOpen = false;
    _lastNativeRequestId = null;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColor = isDark ? Colors.black : Colors.white70;

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
        child: _buildBottomBar(gradColor),
      ),
      body: Stack(
        children: [
          Column(children: [Expanded(child: _buildBody())]),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color gradColor) {
    return BlocBuilder<ChatModelSwitchingCubit, ChatModelSwitchState>(
      builder: (context, switchState) {
        return BlocBuilder<SelectedChatCubit, String?>(
          builder: (context, selectedChat) {
            return StreamBuilder<ModelInfo?>(
              stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
              builder: (context, activeModelSnapshot) {
                final activeModel = activeModelSnapshot.data;
                final canShowInput =
                    selectedChat != null && activeModel != null;

                final bottomBar = !canShowInput
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        ignoring: switchState.isBusy,
                        child: AnimatedOpacity(
                          opacity: switchState.isBusy ? 0.55 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom,
                            ),
                            child: SafeArea(child: ChatInput()),
                          ),
                        ),
                      );

                return bottomBar is SizedBox
                    ? bottomBar
                    : reveal(bottomBar, delayMs: 60);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody() {
    return BlocBuilder<ChatModelSwitchingCubit, ChatModelSwitchState>(
      builder: (context, switchState) {
        return BlocBuilder<SelectedChatCubit, String?>(
          builder: (context, selectedChat) {
            return StreamBuilder<ModelInfo?>(
              stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
              builder: (context, activeModelSnapshot) {
                final activeModel = activeModelSnapshot.data;

                return _buildChatContent(
                  context: context,
                  selectedChat: selectedChat,
                  activeModel: activeModel,
                  switchState: switchState,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatContent({
    required BuildContext context,
    required String? selectedChat,
    required ModelInfo? activeModel,
    required ChatModelSwitchState switchState,
  }) {
    return BlocListener<NativeToolExecutionCubit, NativeToolExecutionState>(
      listener: (context, state) {
        final request = state.currentRequest;
        if (request == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showNativeActionSheet(context, request);
        });
      },
      child: _buildChatBody(
        context: context,
        selectedChat: selectedChat,
        activeModel: activeModel,
        switchState: switchState,
      ),
    );
  }

  Widget _buildChatBody({
    required BuildContext context,
    required String? selectedChat,
    required ModelInfo? activeModel,
    required ChatModelSwitchState switchState,
  }) {
    final body = selectedChat == null
        ? reveal(const Center(child: Text('Select or create a chat')))
        : activeModel == null
        ? reveal(const Center(child: Text('No active model')))
        : ChatView(
            chatId: selectedChat,
          ).animate().fadeIn(duration: Duration(milliseconds: 1200));

    final showStatus =
        switchState.isBusy || switchState.phase == ChatModelSwitchPhase.failed;
    return Stack(
      children: [
        Positioned.fill(
          child: KeyedSubtree(
            key: ValueKey(selectedChat ?? 'none'),
            child: body,
          ),
        ),
        if (showStatus)
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            left: 16,
            right: 16,
            child: ChatModelSwitchStatusBanner(
              state: switchState,
              onRetry: sl<ChatPageActions>().retryLastModelSwitch,
            ),
          ),
      ],
    );
  }
}

class ChatModelSwitchStatusBanner extends StatelessWidget {
  const ChatModelSwitchStatusBanner({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final ChatModelSwitchState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isFailed = state.phase == ChatModelSwitchPhase.failed;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: isFailed
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isFailed ? Icons.error_outline_rounded : Icons.memory_rounded,
                  size: 18,
                  color: isFailed ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (isFailed)
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
          if (state.isBusy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  String get _label {
    final modelName = state.modelName ?? 'model';
    return switch (state.phase) {
      ChatModelSwitchPhase.stoppingGeneration =>
        'Stopping the current response…',
      ChatModelSwitchPhase.unloading => 'Releasing the current model…',
      ChatModelSwitchPhase.loading => 'Loading $modelName…',
      ChatModelSwitchPhase.failed =>
        state.errorMessage ?? 'Could not load $modelName.',
      ChatModelSwitchPhase.idle || ChatModelSwitchPhase.ready => modelName,
    };
  }
}
