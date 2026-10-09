import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/data/services/whisper_model_provisioner.dart';
import 'package:gena/features/chat/presentation/cubit/whisper_model_cubit.dart';
import 'package:gena/features/setting/presentation/widgets/whisper_model_settings_section.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  testWidgets('shows tiny as recommended and confirms before base', (
    tester,
  ) async {
    final cubit = WhisperModelCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WhisperModelSettingsSection(cubit: cubit)),
      ),
    );

    expect(find.text('Voice & audio'), findsOneWidget);
    expect(find.textContaining('Tiny'), findsWidgets);
    expect(find.textContaining('Recommended for 4 GB'), findsOneWidget);
    expect(find.textContaining('Base'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('whisper-profile-base')));
    await tester.pumpAndSettle();

    expect(find.text('Use the Base Whisper model?'), findsOneWidget);
    expect(cubit.state.profile, WhisperModelProfile.tiny);

    await tester.tap(find.text('Use Base'));
    await tester.pumpAndSettle();

    expect(cubit.state.profile, WhisperModelProfile.base);
  });

  testWidgets('shows preparation progress immediately after selection', (
    tester,
  ) async {
    final manager = _BlockingModelManager();
    final cubit = WhisperModelCubit(modelManager: manager);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WhisperModelSettingsSection(cubit: cubit)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('whisper-profile-base')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Base'));
    await tester.pump();

    expect(manager.ensuredProfiles, <WhisperModelProfile>[
      WhisperModelProfile.base,
    ]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('40% · Loading Base'), findsOneWidget);
    expect(find.text('Cancel preparation'), findsOneWidget);

    manager.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('ready'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });
}

class _BlockingModelManager implements WhisperModelManager {
  final ensuredProfiles = <WhisperModelProfile>[];
  final _ready = Completer<void>();

  @override
  Future<bool> cancel(WhisperModelProfile profile) async => true;

  @override
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  }) async {
    ensuredProfiles.add(profile);
    onProgress?.call(0.4, 'Loading ${profile.label}');
    await _ready.future;
    onProgress?.call(1, '${profile.label} is ready');
    return '/models/${profile.fileName}';
  }

  @override
  Future<bool> isInstalled(WhisperModelProfile profile) async => false;

  void complete() => _ready.complete();
}
