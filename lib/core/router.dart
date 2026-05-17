import 'package:flutter/material.dart';
import 'package:gena/features/chat/presentation/chat_page.dart';
import 'package:gena/features/downloads/presentation/download_page.dart';
import 'package:gena/features/setting/presentation/model_setting_page.dart';
import 'package:go_router/go_router.dart';

import '../features/setting/presentation/setting_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: "home",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const ChatPage()),
    ),
    GoRoute(
      path: '/chat/:id',
      name: "chat",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const ChatPage()),
    ),
    GoRoute(
      path: '/download',
      name: "download",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const DownloadPage()),
    ),
    GoRoute(
      path: '/settings',
      name: "setting",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const SettingsPage()),
    ),
    GoRoute(
      path: '/settings/model',
      name: "model-setting",
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const ModelSettingsPage()),
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
    transitionDuration: const Duration(milliseconds: 1000),
    reverseTransitionDuration: const Duration(milliseconds: 200),
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
