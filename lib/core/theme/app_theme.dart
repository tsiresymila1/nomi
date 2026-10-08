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
  static const _lightPrimary = Color(0xFF006B55);

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
      bodyLarge: scale(source.bodyLarge)?.copyWith(fontSize: 14),
      bodyMedium: scale(source.bodyMedium),
      bodySmall: scale(source.bodySmall),
      labelLarge: scale(source.labelLarge),
      labelMedium: scale(source.labelMedium),
      labelSmall: scale(source.labelSmall),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      hintStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static ListTileThemeData _listTileTheme({
    required TextTheme textTheme,
    required ColorScheme scheme,
  }) {
    return ListTileThemeData(
      dense: true,
      minVerticalPadding: 0,
      horizontalTitleGap: 8,
      contentPadding: EdgeInsets.symmetric(horizontal: 12),
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
        fontFamily: textTheme.bodyMedium?.fontFamily,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
        fontFamily: textTheme.bodyMedium?.fontFamily,
      ),
      iconColor: scheme.onSurfaceVariant,
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
        seedColor: _pureGreen,
        brightness: Brightness.light,
      ),
    );
    final scheme = base.colorScheme.copyWith(
      primary: _lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFA4F2D4),
      onPrimaryContainer: const Color(0xFF002118),
      onSurface: const Color(0xFF171D1A),
      onSurfaceVariant: const Color(0xFF3F4944),
      outline: const Color(0xFF6F7973),
      outlineVariant: const Color(0xFFBFC9C3),
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
    final appTextTheme = _scaledTextTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final appPrimaryTextTheme = _scaledTextTheme(
      base.primaryTextTheme,
    ).apply(bodyColor: scheme.onPrimary, displayColor: scheme.onPrimary);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: appTextTheme,
      primaryTextTheme: appPrimaryTextTheme,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      dividerColor: scheme.outlineVariant,
      inputDecorationTheme: _inputDecorationTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.light),
      drawerTheme: _drawerTheme(scheme.surfaceContainerLow),
      listTileTheme: _listTileTheme(textTheme: appTextTheme, scheme: scheme),
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
    final appTextTheme = _scaledTextTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final appPrimaryTextTheme = _scaledTextTheme(
      base.primaryTextTheme,
    ).apply(bodyColor: scheme.onPrimary, displayColor: scheme.onPrimary);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: appTextTheme,
      primaryTextTheme: appPrimaryTextTheme,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      dividerColor: scheme.outlineVariant,
      inputDecorationTheme: _inputDecorationTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      appBarTheme: _appBarTheme(Brightness.dark),
      drawerTheme: _drawerTheme(scheme.surfaceContainerLow),
      listTileTheme: _listTileTheme(textTheme: appTextTheme, scheme: scheme),
      switchTheme: _switchTheme(),
    );
  }
}
