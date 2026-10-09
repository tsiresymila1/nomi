import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/widgets/image_generation_chat_activity.dart';

void main() {
  test('activity belongs only to its active chat and generation phase', () {
    const state = ImageGenerationState(
      phase: ImageGenerationUiPhase.generating,
      isInstalled: true,
      activePrompt: 'A quiet harbor',
      activeChatId: '12',
    );

    expect(shouldShowImageGenerationActivity(state, '12'), isTrue);
    expect(shouldShowImageGenerationActivity(state, '13'), isFalse);
    expect(
      shouldShowImageGenerationActivity(
        const ImageGenerationState(
          phase: ImageGenerationUiPhase.completed,
          activePrompt: 'A quiet harbor',
          activeChatId: '12',
        ),
        '12',
      ),
      isFalse,
    );
  });

  testWidgets('shows model loading as an assistant chat item', (tester) async {
    var cancelCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationChatActivity(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.loadingModel,
              isInstalled: true,
              activePrompt: 'A quiet harbor',
              activeChatId: '12',
            ),
            onCancel: () => cancelCalls += 1,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Loading SDXS-512'), findsOneWidget);
    expect(find.byKey(const ValueKey('image-generation-activity')), findsOne);
    await tester.tap(find.text('Cancel'));
    expect(cancelCalls, 1);
  });

  testWidgets('shows generation progress and stop action', (tester) async {
    var stopCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationChatActivity(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.generating,
              isInstalled: true,
              activePrompt: 'A quiet harbor',
              activeChatId: '12',
              progress: LocalImageGenerationProgress(
                phase: LocalImageGenerationPhase.sampling,
                step: 1,
                steps: 4,
              ),
            ),
            onCancel: () => stopCalls += 1,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Drawing image · 1/4'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(stopCalls, 1);
  });

  testWidgets('shows a retry action after failure', (tester) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationChatActivity(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.failed,
              isInstalled: true,
              activePrompt: 'A quiet harbor',
              activeChatId: '12',
              errorMessage: 'Out of memory',
            ),
            onCancel: () {},
            onRetry: () => retryCalls += 1,
          ),
        ),
      ),
    );

    expect(find.text('Image generation failed'), findsOneWidget);
    expect(find.text('Out of memory'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCalls, 1);
  });

  testWidgets('shows retry after cancellation', (tester) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationChatActivity(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.cancelled,
              isInstalled: true,
              activePrompt: 'A quiet harbor',
              activeChatId: '12',
            ),
            onCancel: () {},
            onRetry: () => retryCalls += 1,
          ),
        ),
      ),
    );

    expect(find.text('Image generation cancelled'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCalls, 1);
  });
}
