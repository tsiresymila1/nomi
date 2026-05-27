import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/domain/web_storage_mode.dart';
import 'package:flutter/services.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/router.dart';
import 'package:gena/core/theme/app_theme.dart';
import 'package:gena/core/theme/theme_cubit.dart';
import 'package:gena/features/chat/data/chat_service_locator.dart';
import 'package:gena/features/downloads/data/downloads_service_locator.dart';
import 'package:gena/features/home/presentation/app_introduction_gate.dart';
import 'package:gena/features/home/presentation/cubit/home_service_locator.dart';
import 'package:gena/features/remote_servers/data/remote_servers_service_locator.dart';
import 'package:gena/features/setting/data/settings_service_locator.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await setupServiceLocator();
  registerDownloadsDependencies();
  registerRemoteServersDependencies();
  registerSettingsDependencies();
  registerChatDependencies();
  registerHomeDependencies();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getTemporaryDirectory()).path,
    ),
  );
  await FlutterGemma.initialize(
    huggingFaceToken: dotenv.env['HUGGING_FACE_TOKEN']!,
    webStorageMode: WebStorageMode.cacheApi,
  );

  runApp(const GenaApp());
}

class GenaApp extends StatelessWidget {
  const GenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<ThemeCubit>(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
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
                child: AppIntroductionGate(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            theme: AppTheme.light().copyWith(
              extensions: [
                GptMarkdownThemeData(
                  brightness: Brightness.light,
                  linkColor: Colors.indigo,
                  linkHoverColor: Colors.blueAccent,
                  autoAddDividerLineAfterH1: true,
                  h1: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  h2: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  h4: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  h5: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  h6: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            darkTheme: AppTheme.dark().copyWith(
              extensions: [
                GptMarkdownThemeData(
                  brightness: Brightness.dark,
                  linkColor: Colors.lightBlueAccent,
                  h1: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  h2: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  h4: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  h5: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  h6: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            themeMode: themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
