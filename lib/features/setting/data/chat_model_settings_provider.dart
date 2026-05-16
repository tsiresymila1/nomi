import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final chatModelSettingsProvider =
    NotifierProvider<ChatModelSettingsNotifier, ChatModelSettings>(
      ChatModelSettingsNotifier.new,
    );

class ChatModelSettingsNotifier extends Notifier<ChatModelSettings> {
  bool _hydrated = false;

  @override
  ChatModelSettings build() {
    _hydrate();
    return ChatModelSettings.defaults();
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final prefs = await SharedPreferences.getInstance();
    state = ChatModelSettings.fromPrefs(prefs);
  }

  Future<void> save(ChatModelSettings next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await next.saveToPrefs(prefs);
  }

  Future<void> resetDefaults() async {
    final defaults = ChatModelSettings.defaults();
    await save(defaults);
  }
}
