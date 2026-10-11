import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';
import 'package:gena/features/chat/presentation/widgets/voice_crystal_orb.dart';

void main() {
  testWidgets('renders the moving crystal orb with phase semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceCrystalOrb(
            phase: VoiceConversationPhase.listening,
            micLevel: 0.6,
            accentColor: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('voice-crystal-orb')), findsOneWidget);
    expect(find.bySemanticsLabel('Voice assistant listening'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
  });

  testWidgets('updates its accessible phase when the assistant speaks', (
    tester,
  ) async {
    Widget buildOrb(VoiceConversationPhase phase) {
      return MaterialApp(
        home: Scaffold(
          body: VoiceCrystalOrb(
            phase: phase,
            micLevel: 0,
            accentColor: Colors.blue,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildOrb(VoiceConversationPhase.listening));
    await tester.pumpWidget(buildOrb(VoiceConversationPhase.speaking));

    expect(find.bySemanticsLabel('Voice assistant speaking'), findsOneWidget);
  });
}
