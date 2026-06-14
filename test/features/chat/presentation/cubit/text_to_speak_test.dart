import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/text_to_speak.dart';

void main() {
  test('strips common markdown formatting to plain spoken text', () {
    const markdown =
        '# Heading\n'
        '**Bold** and *italic* and `code` words.\n'
        '- bullet item\n'
        '> quoted line\n'
        'See [the docs](https://example.com) for more.\n'
        '```dart\nprint("hi");\n```';

    final spoken = stripMarkdownForSpeech(markdown);

    expect(spoken, isNot(contains('**')));
    expect(spoken, isNot(contains('`')));
    expect(spoken, isNot(contains('#')));
    expect(spoken, isNot(contains('](')));
    expect(spoken, isNot(contains('```')));
    expect(spoken, isNot(contains('https://example.com')));
    expect(spoken, contains('Bold'));
    expect(spoken, contains('the docs'));
    expect(spoken, contains('bullet item'));
    expect(spoken, contains('quoted line'));
    expect(spoken, contains('print("hi");'));
  });

  test('keeps link/image alt text and drops urls', () {
    expect(
      stripMarkdownForSpeech('![a cat](cat.png) and [home](/index)'),
      'a cat and home',
    );
  });

  test('trims and collapses whitespace', () {
    // Runs of spaces/tabs collapse to one; blank lines collapse to a single
    // newline; leading/trailing whitespace is trimmed.
    expect(
      stripMarkdownForSpeech('  hello   world  \n\n\n more '),
      'hello world \n more',
    );
  });

  test('empty input yields empty output', () {
    expect(stripMarkdownForSpeech(''), '');
    expect(stripMarkdownForSpeech('   \n  '), '');
  });
}
