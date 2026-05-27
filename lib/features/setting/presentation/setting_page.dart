import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<ThemeCubit>(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          final isDark = themeMode == ThemeMode.dark;

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                SwitchListTile(
                      title: const Text(
                        'Dark mode',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        isDark ? 'Dark theme enabled' : 'Light theme enabled',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: isDark,
                      onChanged: (_) {
                        context.read<ThemeCubit>().toggleLightDark();
                      },
                      secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 220.ms, delay: 60.ms)
                    .slideY(begin: 0.08, end: 0),
                const SizedBox(height: 8),
                ListTile(
                      title: const Text(
                        'Remote servers',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Manage scanned/manual servers and sync remote model catalog',
                        style: TextStyle(fontSize: 13),
                      ),
                      leading: const Icon(Icons.cloud_outlined),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () => context.pushNamed('remote-servers'),
                    )
                    .animate()
                    .fadeIn(duration: 220.ms, delay: 100.ms)
                    .slideY(begin: 0.08, end: 0),
              ],
            ),
          );
        },
      ),
    );
  }
}
