import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/domain/web_storage_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:gena/core/router.dart';
import 'package:gena/core/theme/app_theme.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await FlutterGemma.initialize(
    huggingFaceToken: dotenv.env['HUGGING_FACE_TOKEN']!,
    webStorageMode: WebStorageMode.cacheApi,
  );

  runApp(const ProviderScope(child: GenaApp()));
}

class GenaApp extends ConsumerWidget {
  const GenaApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gena',
      builder: (context, child) {
        final isDark = themeMode == ThemeMode.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: AppTheme.light().copyWith(
        extensions: [
          GptMarkdownThemeData(
            brightness: Brightness.light,
            linkColor: Colors.indigo,
            linkHoverColor: Colors.blueAccent,
            autoAddDividerLineAfterH1: true,
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            h4: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            h5: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            h6: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      darkTheme: AppTheme.dark().copyWith(
        extensions: [
          GptMarkdownThemeData(
            brightness: Brightness.dark,
            linkColor: Colors.lightBlueAccent,
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            h4: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            h5: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            h6: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
