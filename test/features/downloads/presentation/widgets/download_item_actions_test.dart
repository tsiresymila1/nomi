import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item_actions.dart';

void main() {
  testWidgets('keeps download primary and moves secondary actions to menu', (
    tester,
  ) async {
    var downloaded = false;
    var edited = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadItemActions(
            isDownloading: false,
            isRemote: false,
            isNetworkSource: true,
            canRemove: true,
            canDeleteDownloadedFile: false,
            isInstalled: false,
            onEdit: () => edited = true,
            onDownload: () => downloaded = true,
            onRemove: () {},
            onDeleteDownloadedFile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('model-primary-download')));
    expect(downloaded, isTrue);

    await tester.tap(find.byKey(const ValueKey('model-more-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Edit details'), findsOneWidget);

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });
}
