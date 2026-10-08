import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';

void main() {
  group('LocalAiRuntimeCoordinator', () {
    test('evicts the resident chat runtime before granting STT', () async {
      final events = <String>[];
      final coordinator = LocalAiRuntimeCoordinator(
        requiresExclusiveAccess: () async => true,
      );
      addTearDown(coordinator.close);

      final chatLease = await coordinator.acquire(
        LocalAiWorkload.chat,
        onEvict: () async => events.add('chat:evicted'),
      );
      expect(chatLease.isActive, isTrue);

      final sttLease = await coordinator.acquire(
        LocalAiWorkload.speechToText,
        onEvict: () async => events.add('stt:evicted'),
      );

      expect(events, ['chat:evicted']);
      expect(chatLease.isActive, isFalse);
      expect(sttLease.isActive, isTrue);
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.speechToText});

      await sttLease.release();
      expect(coordinator.state.phase, LocalAiRuntimePhase.idle);
    });

    test(
      'waits for eviction to finish before granting the next lease',
      () async {
        final releaseChat = Completer<void>();
        final coordinator = LocalAiRuntimeCoordinator(
          requiresExclusiveAccess: () async => true,
        );
        addTearDown(coordinator.close);
        await coordinator.acquire(
          LocalAiWorkload.chat,
          onEvict: () => releaseChat.future,
        );

        var sttGranted = false;
        final pendingStt = coordinator
            .acquire(LocalAiWorkload.speechToText, onEvict: () async {})
            .then((lease) {
              sttGranted = true;
              return lease;
            });
        await Future<void>.delayed(Duration.zero);

        expect(sttGranted, isFalse);
        expect(coordinator.state.phase, LocalAiRuntimePhase.releasing);

        releaseChat.complete();
        final sttLease = await pendingStt;
        expect(sttGranted, isTrue);
        expect(sttLease.isActive, isTrue);
      },
    );

    test(
      'allows independent heavy workloads on an unconstrained profile',
      () async {
        var chatEvictions = 0;
        final coordinator = LocalAiRuntimeCoordinator(
          requiresExclusiveAccess: () async => false,
        );
        addTearDown(coordinator.close);
        final chatLease = await coordinator.acquire(
          LocalAiWorkload.chat,
          onEvict: () async => chatEvictions++,
        );
        final sttLease = await coordinator.acquire(
          LocalAiWorkload.speechToText,
          onEvict: () async {},
        );

        expect(chatEvictions, 0);
        expect(chatLease.isActive, isTrue);
        expect(sttLease.isActive, isTrue);
        expect(coordinator.state.activeWorkloads, {
          LocalAiWorkload.chat,
          LocalAiWorkload.speechToText,
        });
      },
    );

    test('never grants overlap when eviction fails', () async {
      final coordinator = LocalAiRuntimeCoordinator(
        requiresExclusiveAccess: () async => true,
      );
      addTearDown(coordinator.close);
      final chatLease = await coordinator.acquire(
        LocalAiWorkload.chat,
        onEvict: () async => throw StateError('dispose failed'),
      );

      await expectLater(
        coordinator.acquire(LocalAiWorkload.diffusion, onEvict: () async {}),
        throwsA(isA<LocalAiCoordinationException>()),
      );

      expect(chatLease.isActive, isTrue);
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.chat});
      expect(coordinator.state.phase, LocalAiRuntimePhase.failed);
    });
  });

  group('requiresExclusiveLocalAiAccess', () {
    test('constrains Android devices with 4 GB or unknown RAM', () {
      expect(
        requiresExclusiveLocalAiAccess(
          platform: 'android',
          totalRamBytes: 4 << 30,
        ),
        isTrue,
      );
      expect(
        requiresExclusiveLocalAiAccess(platform: 'android', totalRamBytes: 0),
        isTrue,
      );
    });

    test('does not constrain Android devices above the safety threshold', () {
      expect(
        requiresExclusiveLocalAiAccess(
          platform: 'android',
          totalRamBytes: 8 << 30,
        ),
        isFalse,
      );
    });

    test('does not apply the Android profile to other platforms', () {
      expect(
        requiresExclusiveLocalAiAccess(platform: 'ios', totalRamBytes: 4 << 30),
        isFalse,
      );
    });
  });
}
