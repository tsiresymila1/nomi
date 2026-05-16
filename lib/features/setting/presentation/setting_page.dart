import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/setting/data/theme_settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Model settings'),
            subtitle: const Text('Prompt, temperature, tokens, backend'),
            leading: const Icon(Icons.tune),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('model-setting'),
          ),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: Text(
              isDark ? 'Dark theme enabled' : 'Light theme enabled',
            ),
            value: isDark,
            onChanged: (_) {
              ref.read(themeModeProvider.notifier).toggleLightDark();
            },
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
      ),
    );
  }
}
