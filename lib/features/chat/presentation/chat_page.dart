import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
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
    final coloScheme = Theme.of(context).colorScheme;
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
          Column(children: [Expanded(child: _buildBody(coloScheme))]),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color gradColor) {
    return BlocBuilder<ChatModelSwitchingCubit, bool>(
      builder: (context, isSwitchingModel) {
        return BlocBuilder<SelectedChatCubit, String?>(
          builder: (context, selectedChat) {
            return StreamBuilder<ModelInfo?>(
              stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
              builder: (context, activeModelSnapshot) {
                final activeModel = activeModelSnapshot.data;
                final canShowInput =
                    !isSwitchingModel &&
                    selectedChat != null &&
                    activeModel != null;

                final bottomBar = !canShowInput
                    ? const SizedBox.shrink()
                    : AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: SafeArea(child: ChatInput()),
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

  Widget _buildBody(ColorScheme coloScheme) {
    return BlocBuilder<ChatModelSwitchingCubit, bool>(
      builder: (context, isSwitchingModel) {
        return BlocBuilder<SelectedChatCubit, String?>(
          builder: (context, selectedChat) {
            return StreamBuilder<ModelInfo?>(
              stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
              builder: (context, activeModelSnapshot) {
                final activeModel = activeModelSnapshot.data;

                return _buildChatContent(
                  context: context,
                  coloScheme: coloScheme,
                  selectedChat: selectedChat,
                  activeModel: activeModel,
                  isSwitchingModel: isSwitchingModel,
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
    required ColorScheme coloScheme,
    required String? selectedChat,
    required ModelInfo? activeModel,
    required bool isSwitchingModel,
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
        coloScheme: coloScheme,
        selectedChat: selectedChat,
        activeModel: activeModel,
        isSwitchingModel: isSwitchingModel,
      ),
    );
  }

  Widget _buildChatBody({
    required BuildContext context,
    required ColorScheme coloScheme,
    required String? selectedChat,
    required ModelInfo? activeModel,
    required bool isSwitchingModel,
  }) {
    final body = selectedChat == null
        ? reveal(const Center(child: Text('Select or create a chat')))
        : activeModel == null
        ? reveal(const Center(child: Text('No active model')))
        : ChatView(
            chatId: selectedChat,
          ).animate().fadeIn(duration: Duration(milliseconds: 1200));

    return AnimatedSwitcher(
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
              isSwitchingModel && selectedChat != null && activeModel != null,
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
                  isSwitchingModel ? 'Loading model...' : 'No active chat',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
