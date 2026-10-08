import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';
import 'package:gena/features/chat/presentation/voice_conversation_page.dart';

void main() {
  testWidgets('shows recoverable error and cancels an active voice turn', (
    tester,
  ) async {
    var cancelCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConversationStatus(
            state: const VoiceConversationState(
              phase: VoiceConversationPhase.thinking,
              partialTranscript: 'Hello Nomi',
              errorMessage: 'Previous turn failed',
            ),
            onCancelTurn: () async => cancelCalls++,
          ),
        ),
      ),
    );

    expect(find.text('Thinking… (tap to cancel)'), findsOneWidget);
    expect(find.text('Hello Nomi'), findsOneWidget);
    expect(find.text('Previous turn failed'), findsOneWidget);

    await tester.tap(find.text('Cancel current turn'));
    await tester.pump();
    expect(cancelCalls, 1);
  });

  testWidgets('does not show cancel action while listening', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConversationStatus(
            state: const VoiceConversationState(
              phase: VoiceConversationPhase.listening,
            ),
            onCancelTurn: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Listening…'), findsOneWidget);
    expect(find.text('Cancel current turn'), findsNothing);
  });
}
