import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_tile.dart';

void main() {
  testWidgets(
    'shows sync directly and keeps secondary server actions in menu',
    (tester) async {
      var synced = false;
      var tested = false;
      final server = RemoteServerEntry(
        id: 'local',
        name: 'Local server',
        baseUrl: 'http://192.168.1.2:11434/v1',
        token: '',
        autoDiscovered: false,
        createdAt: DateTime(2026, 1, 1),
        lastSeenAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteServerTile(
              server: server,
              modelCount: 3,
              busy: false,
              onTest: () => tested = true,
              onSync: () => synced = true,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('3 models'), findsOneWidget);
      expect(find.text('Test connection'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('remote-server-sync')));
      expect(synced, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('remote-server-more-actions')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test connection'), findsOneWidget);

      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(tested, isTrue);
    },
  );
}
