import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class ThemeCubit extends HydratedCubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark);

  void setMode(ThemeMode mode) {
    emit(mode);
  }

  void toggleLightDark() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  ThemeMode? fromJson(Map<String, dynamic> json) {
    final raw = json['themeMode'] as String?;
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  @override
  Map<String, dynamic>? toJson(ThemeMode state) {
    final raw = switch (state) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'dark',
    };
    return {'themeMode': raw};
  }
}
