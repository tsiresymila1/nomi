import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const double _defaultFontSize = 13;
  static const double _materialBaseBodySize = 16;
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
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      hintStyle: TextStyle(fontSize: 14),
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

  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      shadowColor: Colors.transparent,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
    );
  }

  static DrawerThemeData _drawerTheme(Color backgroundColor) {
    return DrawerThemeData(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green.shade900,
        brightness: Brightness.light,
      ),
    );
    final robotoTextTheme = _scaledTextTheme(base.textTheme);
    final robotoPrimaryTextTheme = _scaledTextTheme(base.primaryTextTheme);
    return base.copyWith(
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.light),
      drawerTheme: _drawerTheme(base.colorScheme.surface),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green.shade700,
        brightness: Brightness.dark,
        surface: Colors.black54,
        surfaceTint: Colors.black54,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(),
    );
    final robotoTextTheme = _scaledTextTheme(base.textTheme);
    final robotoPrimaryTextTheme = _scaledTextTheme(base.primaryTextTheme);
    return base.copyWith(
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.dark),
      // drawerTheme: _drawerTheme(base.colorScheme.surface),
    );
  }
}
