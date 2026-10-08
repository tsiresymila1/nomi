import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item.dart';

void main() {
  testWidgets('shows progress percentage beside the expanded progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadItem(
            model: _model,
            insight: null,
            progress: 0.37,
            isInstalled: false,
            canRemove: false,
            canDeleteDownloadedFile: false,
            onDownload: () {},
            onRemove: () {},
            onCancelDownload: () {},
            onDeleteDownloadedFile: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(_model.name));
    await tester.pumpAndSettle();

    // One value is in the compact status badge and one stays beside the bar.
    expect(find.text('37%'), findsNWidgets(2));
  });
}

const _model = ModelInfo(
  id: 1,
  name: 'Tiny GGUF',
  description: 'A small local model',
  provider: ModelProviderType.local,
  modelType: 'gguf',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.9,
  maxTokens: 1024,
  tokenBuffer: 64,
  randomSeed: 42,
  preferredBackend: 'llamadart',
  sourceType: 'network',
  source: 'https://example.com/model.gguf',
);
