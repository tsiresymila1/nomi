import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';

LlamaDartTtsModelStore createPlatformLlamaDartTtsModelStore() =>
    const UnsupportedLlamaDartTtsModelStore();

class UnsupportedLlamaDartTtsModelStore implements LlamaDartTtsModelStore {
  const UnsupportedLlamaDartTtsModelStore();

  @override
  bool get isSupported => false;

  @override
  Future<void> cancelInstall(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<void> delete(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) => throw UnsupportedError(
    'LlamaDart text-to-speech is unavailable on this platform.',
  );

  @override
  Future<InstalledLlamaDartTtsModel?> resolve(
    LlamaDartTtsModelProfile profile,
  ) async => null;
}
