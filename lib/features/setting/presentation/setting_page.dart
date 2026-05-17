import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding:  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ListTile(
            title: const Text('Model settings'),
            subtitle: const Text('Prompt, temperature, tokens, backend'),
            leading: const Icon(Icons.tune),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('model-setting'),
          ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.08, end: 0),
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
              )
              .animate()
              .fadeIn(duration: 220.ms, delay: 60.ms)
              .slideY(begin: 0.08, end: 0),
        ],
      ),
    );
  }
}
