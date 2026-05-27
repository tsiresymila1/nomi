import 'dart:async';

import 'package:gena/features/chat/data/cubits/selected_model_cubit.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

class ActiveModelInfoResolver {
  ActiveModelInfoResolver({
    required ModelRepository modelRepository,
    required SelectedModelCubit selectedModelCubit,
  }) : _modelRepository = modelRepository,
       _selectedModelCubit = selectedModelCubit;

  final ModelRepository _modelRepository;
  final SelectedModelCubit _selectedModelCubit;

  Future<ModelInfo?> getActiveModelInfo() async {
    final models = await _modelRepository.watchModels().first;
    final selectedId = _selectedModelCubit.state;
    if (selectedId == null) return null;
    for (final model in models) {
      if (model.id == selectedId) return model;
    }
    return null;
  }

  Stream<ModelInfo?> watchActiveModelInfo() {
    late final StreamController<ModelInfo?> controller;
    StreamSubscription<List<ModelInfo>>? modelsSub;
    StreamSubscription<int?>? selectedSub;
    List<ModelInfo> models = const <ModelInfo>[];

    void emitCurrent() {
      final selectedId = _selectedModelCubit.state;
      ModelInfo? active;
      if (selectedId != null) {
        for (final model in models) {
          if (model.id == selectedId) {
            active = model;
            break;
          }
        }
      }
      if (!controller.isClosed) {
        controller.add(active);
      }
    }

    controller = StreamController<ModelInfo?>.broadcast(
      onListen: () {
        modelsSub = _modelRepository.watchModels().listen((next) {
          models = next;
          emitCurrent();
        });
        selectedSub = _selectedModelCubit.stream.listen((_) => emitCurrent());
        emitCurrent();
      },
      onCancel: () async {
        await modelsSub?.cancel();
        await selectedSub?.cancel();
      },
    );

    return controller.stream;
  }
}
