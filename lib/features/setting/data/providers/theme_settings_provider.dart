import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _hydrated = false;

  @override
  ThemeMode build() {
    _hydrate();
    return ThemeMode.dark;
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey) ?? 'light';
    state = _fromRaw(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _toRaw(mode));
  }

  Future<void> toggleLightDark() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  ThemeMode _fromRaw(String raw) {
    return switch (raw) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  String _toRaw(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      _ => 'light',
    };
  }
}
