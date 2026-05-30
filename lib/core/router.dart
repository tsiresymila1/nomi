import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_input_cubit.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_model_cubit.dart';
import 'package:gena/features/chat/presentation/chat_page.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/presentation/add_model_page.dart';
import 'package:gena/features/downloads/presentation/download_page.dart';
import 'package:gena/features/home/presentation/home_page.dart';
import 'package:gena/features/remote_servers/presentation/remote_servers_page.dart';
import 'package:go_router/go_router.dart';

import '../features/setting/presentation/setting_page.dart';
import '../features/workspace/presentation/workspace_config_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: "home",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const HomePage()),
    ),
    GoRoute(
      path: '/chat',
      name: "chat",
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sl<SelectedChatCubit>()),
            BlocProvider.value(value: sl<SelectedModelCubit>()),
            BlocProvider.value(value: sl<ChatModelSwitchingCubit>()),
            BlocProvider.value(value: sl<ChatGeneratingCubit>()),
            BlocProvider.value(value: sl<NativeToolExecutionCubit>()),
            BlocProvider.value(value: sl<ChatDraftResponseCubit>()),
            BlocProvider.value(value: sl<ChatDraftThinkingCubit>()),
            BlocProvider.value(value: sl<ChatToolWaitingCubit>()),
            BlocProvider.value(value: sl<ChatInputCubit>()),
            BlocProvider.value(value: sl<ChatContextWindowCubit>()),
          ],
          child: const ChatPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/download',
      name: "download",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const DownloadPage()),
    ),
    GoRoute(
      path: '/download/add-model',
      name: 'add-model',
      pageBuilder: (context, state) {
        final extra = state.extra;
        final initialModel = extra is ModelInfo ? extra : null;
        return _buildTransitionPage(
          state: state,
          child: AddModelPage(initialModel: initialModel),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      name: "setting",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const SettingsPage()),
    ),
    GoRoute(
      path: '/remote-servers',
      name: 'remote-servers',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const RemoteServersPage()),
    ),
    GoRoute(
      path: '/settings/workspace/:workspaceId/config',
      name: "workspace-config",
      pageBuilder: (context, state) {
        final workspaceId = state.pathParameters['workspaceId'];
        return _buildTransitionPage(
          state: state,
          child: WorkspaceConfigPage(workspaceId: workspaceId!),
        );
      },
    ),
  ],
);

CustomTransitionPage<void> _buildTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}
