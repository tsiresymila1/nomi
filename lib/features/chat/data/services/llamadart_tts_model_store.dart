import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';

abstract interface class LlamaDartTtsModelStore {
  bool get isSupported;

  Future<InstalledLlamaDartTtsModel?> resolve(LlamaDartTtsModelProfile profile);

  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  });

  Future<void> cancelInstall(LlamaDartTtsModelProfile profile);

  Future<void> delete(LlamaDartTtsModelProfile profile);
}
