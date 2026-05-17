import 'package:flutter/material.dart';

class AppTheme {
  static const double _defaultFontSize = 13;
  static const double _materialBaseBodySize = 14;
  static const double _fontScale = _defaultFontSize / _materialBaseBodySize;

  static TextTheme _scaledTextTheme(TextTheme source) {
    TextStyle? scale(TextStyle? style) {
      final size = style?.fontSize;
      if (size == null) return style;
      return style!.copyWith(fontSize: size * _fontScale);
    }

    return source.copyWith(
      displayLarge: scale(source.displayLarge),
      displayMedium: scale(source.displayMedium),
      displaySmall: scale(source.displaySmall),
      headlineLarge: scale(source.headlineLarge),
      headlineMedium: scale(source.headlineMedium),
      headlineSmall: scale(source.headlineSmall),
      titleLarge: scale(source.titleLarge),
      titleMedium: scale(source.titleMedium),
      titleSmall: scale(source.titleSmall),
      bodyLarge: scale(source.bodyLarge),
      bodyMedium: scale(source.bodyMedium),
      bodySmall: scale(source.bodySmall),
      labelLarge: scale(source.labelLarge),
      labelMedium: scale(source.labelMedium),
      labelSmall: scale(source.labelSmall),
    );
  }

  static InputDecorationTheme _inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      // fillColor: Colors.grey,
      // border: _noBorder,
      // enabledBorder: _noBorder,
      // focusedBorder: _noBorder,
      // errorBorder: _noBorder,
      // focusedErrorBorder: _noBorder,
      // disabledBorder: _noBorder,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      ),
    );
    final robotoTextTheme = _scaledTextTheme(
      base.textTheme,
    );
    final robotoPrimaryTextTheme = _scaledTextTheme(
      base.primaryTextTheme,
    );
    return base.copyWith(
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(),
    );
    final robotoTextTheme = _scaledTextTheme(
      base.textTheme,
    );
    final robotoPrimaryTextTheme = _scaledTextTheme(
      base.primaryTextTheme,
    );
    return base.copyWith(
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
    );
  }
}
