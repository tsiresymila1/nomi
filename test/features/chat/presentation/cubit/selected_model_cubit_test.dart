import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  group('SelectedModelCubit', () {
    test('starts with no selection', () {
      final cubit = SelectedModelCubit();
      addTearDown(cubit.close);
      expect(cubit.state, isNull);
    });

    test('selectModel emits the chosen id', () async {
      final cubit = SelectedModelCubit();
      addTearDown(cubit.close);

      await cubit.selectModel(7);
      expect(cubit.state, 7);
    });

    test('selecting the already-selected id does not re-emit', () async {
      final cubit = SelectedModelCubit();
      addTearDown(cubit.close);
      await cubit.selectModel(7);

      final emitted = <int?>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await cubit.selectModel(7);
      expect(cubit.state, 7);
      expect(emitted, isEmpty);
    });

    test('clearSelection resets to null', () async {
      final cubit = SelectedModelCubit();
      addTearDown(cubit.close);
      await cubit.selectModel(3);

      await cubit.clearSelection();
      expect(cubit.state, isNull);
    });

    group('hydration', () {
      test('fromJson reads an int id', () {
        final cubit = SelectedModelCubit();
        addTearDown(cubit.close);
        expect(cubit.fromJson(<String, dynamic>{'selectedModelId': 9}), 9);
      });

      test('fromJson coerces a numeric id to int', () {
        final cubit = SelectedModelCubit();
        addTearDown(cubit.close);
        expect(cubit.fromJson(<String, dynamic>{'selectedModelId': 9.0}), 9);
      });

      test('fromJson returns null for a non-numeric value', () {
        final cubit = SelectedModelCubit();
        addTearDown(cubit.close);
        expect(cubit.fromJson(<String, dynamic>{'selectedModelId': 'x'}),
            isNull);
      });

      test('toJson serializes the current state', () {
        final cubit = SelectedModelCubit();
        addTearDown(cubit.close);
        expect(cubit.toJson(5), <String, dynamic>{'selectedModelId': 5});
        expect(cubit.toJson(null), <String, dynamic>{'selectedModelId': null});
      });

      test('selection persists across instances via storage', () async {
        final first = SelectedModelCubit();
        await first.selectModel(11);
        await first.close();

        final second = SelectedModelCubit();
        addTearDown(second.close);
        expect(second.state, 11);
      });
    });
  });
}
