import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/theme/theme_cubit.dart';
import 'package:gena/features/setting/data/cubits/chat_model_settings_cubit.dart';

void registerSettingsDependencies() {
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerLazySingleton<ThemeCubit>(ThemeCubit.new);
  }
  if (!sl.isRegistered<ChatModelSettingsCubit>()) {
    sl.registerLazySingleton<ChatModelSettingsCubit>(
      ChatModelSettingsCubit.new,
    );
  }
}
