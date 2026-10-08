import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light theme keeps text and controls readable', () {
    final theme = AppTheme.light();
    final scheme = theme.colorScheme;

    expect(
      _contrast(scheme.onSurface, scheme.surface),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(scheme.onPrimary, scheme.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(theme.listTileTheme.titleTextStyle?.color, scheme.onSurface);
    expect(
      theme.listTileTheme.subtitleTextStyle?.color,
      scheme.onSurfaceVariant,
    );
    expect(
      theme.inputDecorationTheme.hintStyle?.color,
      scheme.onSurfaceVariant,
    );
    expect(theme.iconTheme.color, scheme.onSurfaceVariant);
  });
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final lighter = light > dark ? light : dark;
  final darker = light > dark ? dark : light;
  return (lighter + 0.05) / (darker + 0.05);
}
