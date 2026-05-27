import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const double _defaultFontSize = 13;
  static const double _materialBaseBodySize = 18;
  static const double _fontScale = _defaultFontSize / _materialBaseBodySize;
  static const _lightSurface = Color(0xFFF6F7F5);
  static const _lightPanel = Color(0xFFFFFFFF);
  static const _lightPanelSoft = Color(0xFFF1F3EF);
  static const _darkSurface = Color(0xFF0E1110);
  static const _darkPanel = Color(0xFF161A18);
  static const _darkPanelSoft = Color(0xFF1D2320);
  static const _pureGreen = Color(0xFF419E7E);

  static TextTheme _scaledTextTheme(TextTheme source) {
    TextStyle? scale(TextStyle? style) {
      final size = style?.fontSize;
      if (size == null) return style;
      return style!.copyWith(
        fontSize: size * _fontScale,
        fontWeight: FontWeight.w400,
      );
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
      bodyLarge: scale(source.bodyLarge)?.copyWith(fontSize: 14),
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
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      hintStyle: TextStyle(fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static ListTileThemeData _listTileTheme() {
    return ListTileThemeData(
      dense: true,
      minVerticalPadding: 0,
      horizontalTitleGap: 8,
      contentPadding: EdgeInsets.symmetric(horizontal: 12),
      titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(fontSize: 12, color: Colors.grey),
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
        textStyle: TextStyle(color: Colors.white),
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
        seedColor: _pureGreen,
        brightness: Brightness.light,
      ),
    );
    final scheme = base.colorScheme.copyWith(
      primary: _pureGreen,
      surface: _lightSurface,
      surfaceDim: _lightPanelSoft,
      surfaceBright: _lightPanel,
      surfaceContainerLowest: _lightPanel,
      surfaceContainerLow: _lightPanel,
      surfaceContainer: _lightPanelSoft,
      surfaceContainerHigh: const Color(0xFFECEFE9),
      surfaceContainerHighest: const Color(0xFFE4E8E1),
      surfaceTint: Colors.transparent,
    );
    final robotoTextTheme = _scaledTextTheme(base.textTheme);
    final robotoPrimaryTextTheme = _scaledTextTheme(base.primaryTextTheme);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.light),
      drawerTheme: _drawerTheme(scheme.surfaceContainerLow),
      listTileTheme: _listTileTheme(),
      switchTheme: _switchTheme(),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _pureGreen,
        brightness: Brightness.dark,
        surface: _darkSurface,
        surfaceTint: Colors.transparent,
        primary: _pureGreen,
        primaryFixed: _pureGreen,
        primaryFixedDim: _pureGreen,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(),
    );
    final scheme = base.colorScheme.copyWith(
      primary: _pureGreen,
      surface: _darkSurface,
      surfaceDim: const Color(0xFF0A0D0C),
      surfaceBright: _darkPanel,
      surfaceContainerLowest: const Color(0xFF0B0E0D),
      surfaceContainerLow: _darkPanel,
      surfaceContainer: _darkPanel,
      surfaceContainerHigh: _darkPanelSoft,
      surfaceContainerHighest: const Color(0xFF252C28),
      surfaceTint: Colors.transparent,
    );
    final robotoTextTheme = _scaledTextTheme(base.textTheme);
    final robotoPrimaryTextTheme = _scaledTextTheme(base.primaryTextTheme);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: robotoTextTheme,
      primaryTextTheme: robotoPrimaryTextTheme,
      inputDecorationTheme: _inputDecorationTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.dark),
      drawerTheme: _drawerTheme(scheme.surfaceContainerLow),
      listTileTheme: _listTileTheme(),
      switchTheme: _switchTheme(),
    );
  }
}
