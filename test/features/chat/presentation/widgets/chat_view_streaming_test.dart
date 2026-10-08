import 'package:flutter_test/flutter_test.dart';
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
}
