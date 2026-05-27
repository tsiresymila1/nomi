import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

final selectedModelIdProvider = NotifierProvider<SelectedModelIdNotifier, int?>(
  SelectedModelIdNotifier.new,
);

class SelectedModelIdNotifier extends Notifier<int?> {
  static const _prefsKey = 'chat_selected_model_id';
  bool _hydrated = false;

  @override
  int? build() {
    _hydrate();
    return stateOrNull;
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_prefsKey);
  }

  Future<void> selectModel(int modelId) async {
    if (state == modelId) return;
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, modelId);
  }

  Future<void> clearSelection() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final activeModelInfoProvider = Provider<ModelInfo?>((ref) {
  final modelsAsync = ref.watch(modelRepositoryProvider);
  final models = modelsAsync.hasValue ? modelsAsync.value : null;
  if (models == null || models.isEmpty) return null;

  final selectedId = ref.watch(selectedModelIdProvider);
  if (selectedId != null) {
    for (final model in models) {
      if (model.id == selectedId) return model;
    }
  }

  return null;
});
