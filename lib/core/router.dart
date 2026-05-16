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
      builder: (context, state) => const ChatPage(),
    ),
    GoRoute(
      path: '/chat/:id',
      name: "chat",
      builder: (context, state) => const ChatPage(),
    ),
    GoRoute(
      path: '/download',
      name: "download",
      builder: (context, state) => const DownloadPage(),
    ),
    GoRoute(
      path: '/settings',
      name: "setting",
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/settings/model',
      name: "model-setting",
      builder: (context, state) => const ModelSettingsPage(),
    ),
  ],
);
