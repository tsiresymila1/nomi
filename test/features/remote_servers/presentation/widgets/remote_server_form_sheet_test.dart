import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_protocol.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_form_sheet.dart';

void main() {
  testWidgets('submits an Anthropic server with the selected protocol', (
    tester,
  ) async {
    RemoteServerProtocol? submittedProtocol;
    String? submittedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => RemoteServerFormSheet(
                  onSubmit: (name, baseUrl, token, protocol) async {
                    submittedProtocol = protocol;
                    submittedUrl = baseUrl;
                  },
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI Compatible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Claude API');
    await tester.enterText(fields.at(1), 'https://api.anthropic.com');
    await tester.enterText(fields.at(2), 'test-key');
    await tester.tap(find.text('Add Server'));
    await tester.pumpAndSettle();

    expect(submittedProtocol, RemoteServerProtocol.anthropic);
    expect(submittedUrl, 'https://api.anthropic.com');
  });

  testWidgets('shows validation instead of silently ignoring empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteServerFormSheet(
            onSubmit: (name, baseUrl, token, protocol) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Server'));
    await tester.pump();

    expect(find.text('Server name and base URL are required.'), findsOneWidget);
  });
}
