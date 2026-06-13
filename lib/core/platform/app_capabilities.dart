import 'package:flutter/foundation.dart';

enum AppPlatform { web, android, iOS, macOS, windows, linux, fuchsia }

class AppCapabilities {
  const AppCapabilities({
    required this.supportsRemoteModels,
    required this.supportsLocalModels,
    required this.supportsWorkspaceRag,
  });

  static const localAiUnavailableMessage =
      'Local models and workspace RAG are unavailable on web. '
      'Remote models remain available.';

  final bool supportsRemoteModels;
  final bool supportsLocalModels;
  final bool supportsWorkspaceRag;

  String get localModelsUnavailableMessage => localAiUnavailableMessage;

  String get workspaceRagUnavailableMessage => localAiUnavailableMessage;

  static AppCapabilities get current => forPlatform(_currentPlatform);

  static AppCapabilities forPlatform(AppPlatform platform) {
    final supportsLocalAi = switch (platform) {
      AppPlatform.android || AppPlatform.iOS || AppPlatform.macOS => true,
      AppPlatform.web ||
      AppPlatform.windows ||
      AppPlatform.linux ||
      AppPlatform.fuchsia => false,
    };

    return AppCapabilities(
      supportsRemoteModels: true,
      supportsLocalModels: supportsLocalAi,
      supportsWorkspaceRag: supportsLocalAi,
    );
  }

  static AppPlatform get _currentPlatform {
    if (kIsWeb) return AppPlatform.web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppPlatform.android,
      TargetPlatform.iOS => AppPlatform.iOS,
      TargetPlatform.macOS => AppPlatform.macOS,
      TargetPlatform.windows => AppPlatform.windows,
      TargetPlatform.linux => AppPlatform.linux,
      TargetPlatform.fuchsia => AppPlatform.fuchsia,
    };
  }
}
