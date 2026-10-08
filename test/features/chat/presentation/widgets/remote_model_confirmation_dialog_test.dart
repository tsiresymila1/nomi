import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/widgets/remote_model_confirmation_dialog.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

void main() {
  testWidgets('names remote model, provider, and data leaving the device', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showRemoteModelConfirmationDialog(
                  context: context,
                  model: _remoteModel(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Switch to a remote model?'), findsOneWidget);
    expect(find.text('Cloud Model'), findsOneWidget);
    expect(find.text('Provider: api.example.com'), findsOneWidget);
    expect(find.textContaining('conversation context'), findsOneWidget);
    expect(find.textContaining('Attached files'), findsOneWidget);

    await tester.tap(find.text('Stay local'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('requires the affirmative action to continue remotely', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showRemoteModelConfirmationDialog(
                  context: context,
                  model: _remoteModel(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue remotely'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('can disclose a remote fallback without a full model record', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showRemoteDataConfirmationDialog(
                  context: context,
                  modelName: 'Fallback model',
                  providerLabel: 'cloud.example.com',
                );
              },
              child: const Text('Open fallback'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open fallback'));
    await tester.pumpAndSettle();

    expect(find.text('Fallback model'), findsOneWidget);
    expect(find.text('Provider: cloud.example.com'), findsOneWidget);
    await tester.tap(find.text('Continue remotely'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

ModelInfo _remoteModel() => const ModelInfo(
  id: 9,
  name: 'Cloud Model',
  description: '',
  provider: 'remote',
  apiUrl: 'https://api.example.com/v1',
  modelType: 'general',
  supportImage: true,
  supportAudio: false,
  supportsFunctionCalls: true,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 4096,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: 'remote',
  source: 'remote-server://server/cloud-model',
);
