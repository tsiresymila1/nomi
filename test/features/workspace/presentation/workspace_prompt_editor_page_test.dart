import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/workspace/presentation/workspace_prompt_editor_page.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('edits and previews a Markdown workspace prompt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkspacePromptEditorPage(initialPrompt: '# Initial prompt'),
      ),
    );

    expect(find.text('Prompt editor'), findsOneWidget);
    expect(find.text('# Initial prompt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('workspace-prompt-editor-field')),
      '# Assistant\n\nAlways cite the workspace.',
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    final preview = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(preview.data, '# Assistant\n\nAlways cite the workspace.');
    expect(find.textContaining('39 characters'), findsOneWidget);
  });

  testWidgets('Markdown toolbar inserts formatting around selected text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkspacePromptEditorPage(initialPrompt: 'safe')),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    expect(editable.controller.text, '**safe**');
  });
}
