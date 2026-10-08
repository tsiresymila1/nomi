import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/widgets/chat_view.dart';

void main() {
  group('isNearChatBottom', () {
    test('is true at the bottom and inside the follow threshold', () {
      expect(isNearChatBottom(pixels: 1000, maxScrollExtent: 1000), isTrue);
      expect(isNearChatBottom(pixels: 890, maxScrollExtent: 1000), isTrue);
    });

    test('is false when the reader scrolls above the threshold', () {
      expect(isNearChatBottom(pixels: 700, maxScrollExtent: 1000), isFalse);
    });

    test('treats short content as already at the bottom', () {
      expect(isNearChatBottom(pixels: 0, maxScrollExtent: 0), isTrue);
    });
  });

  testWidgets('generation failure card exposes retry when recoverable', (
    tester,
  ) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGenerationFailureCard(
            failure: const ChatGenerationFailureState(
              chatId: 1,
              userMessageId: 2,
              displayMessage: 'Could not complete the response.',
              canRetry: true,
            ),
            onRetry: () => retryCalls += 1,
          ),
        ),
      ),
    );

    expect(find.text('Could not complete the response.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retry-generation-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('retry-generation-button')));
    expect(retryCalls, 1);
  });

  testWidgets('generation failure card hides retry when not recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGenerationFailureCard(
            failure: const ChatGenerationFailureState(
              chatId: 1,
              userMessageId: 2,
              displayMessage: 'Reinstall required.',
              canRetry: false,
            ),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Reinstall required.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-generation-button')), findsNothing);
  });

  testWidgets('generation failure card exposes an explicit remote fallback', (
    tester,
  ) async {
    RemoteFallbackProposal? selectedProposal;
    const proposal = RemoteFallbackProposal(
      modelId: 7,
      modelName: 'Cloud rescue',
      providerLabel: 'api.example.com',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGenerationFailureCard(
            failure: const ChatGenerationFailureState(
              chatId: 1,
              userMessageId: 2,
              displayMessage: 'Local generation failed.',
              canRetry: true,
              remoteFallback: proposal,
            ),
            onRetry: () {},
            onRemoteFallback: (value) async => selectedProposal = value,
          ),
        ),
      ),
    );

    expect(find.text('Try Cloud rescue'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('remote-generation-fallback-button')),
    );
    expect(selectedProposal, same(proposal));
  });
}
