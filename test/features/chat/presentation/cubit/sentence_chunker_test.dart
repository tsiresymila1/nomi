import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/sentence_chunker.dart';

void main() {
  late SentenceChunker chunker;

  setUp(() {
    chunker = SentenceChunker();
  });

  test('emits a completed sentence and holds the trailing partial', () {
    // First chunk: one complete sentence + an in-progress one.
    expect(chunker.takeCompletedSentences('Hello there. How are yo'), [
      'Hello there.',
    ]);
    // The partial "How are yo" is held back, not emitted yet.
    expect(chunker.takeCompletedSentences('Hello there. How are you'), isEmpty);
    // Completing the second sentence emits it (and nothing already emitted).
    expect(chunker.takeCompletedSentences('Hello there. How are you? '), [
      'How are you?',
    ]);
  });

  test('does not double-emit sentences as text grows', () {
    expect(chunker.takeCompletedSentences('One. '), ['One.']);
    expect(chunker.takeCompletedSentences('One. Two. '), ['Two.']);
    expect(chunker.takeCompletedSentences('One. Two. Three. '), ['Three.']);
  });

  test('handles ?, ! and newline as terminators', () {
    expect(chunker.takeCompletedSentences('Really?! '), ['Really?!']);
    expect(chunker.takeCompletedSentences('Really?! Wow! '), ['Wow!']);
    expect(chunker.takeCompletedSentences('Really?! Wow! Line one\nmore'), [
      'Line one',
    ]);
  });

  test('emits multiple completed sentences in one growth step', () {
    expect(chunker.takeCompletedSentences('First. Second! Third? trailing'), [
      'First.',
      'Second!',
      'Third?',
    ]);
  });

  test('flush emits the remaining trailing partial', () {
    expect(chunker.takeCompletedSentences('Done. Almost'), ['Done.']);
    expect(chunker.flush('Done. Almost there'), ['Almost there']);
    // Flushing again yields nothing.
    expect(chunker.flush('Done. Almost there'), isEmpty);
  });

  test('does not split on abbreviations or decimals', () {
    expect(
      chunker.takeCompletedSentences('Dr. Smith arrived at 3.14 p.m. '),
      isEmpty,
    );
    expect(chunker.flush('Dr. Smith arrived at 3.14 p.m.'), [
      'Dr. Smith arrived at 3.14 p.m.',
    ]);
  });

  test('strips markdown from each emitted sentence', () {
    final emitted = chunker.takeCompletedSentences(
      'This is **bold** and `code`. See [docs](https://x.io) now. ',
    );
    expect(emitted, hasLength(2));
    expect(emitted[0], isNot(contains('**')));
    expect(emitted[0], contains('bold'));
    expect(emitted[1], isNot(contains('](')));
    expect(emitted[1], contains('docs'));
    expect(emitted.join(' '), isNot(contains('https://x.io')));
  });

  test('skips sentences that strip to empty', () {
    // A line that is only formatting markers strips to empty and is skipped;
    // only the real sentence is emitted.
    final emitted = chunker.takeCompletedSentences('**\nReal sentence. ');
    expect(emitted, ['Real sentence.']);
  });

  test('flush with no remaining text returns empty', () {
    expect(chunker.takeCompletedSentences('All done. '), ['All done.']);
    expect(chunker.flush('All done. '), isEmpty);
  });

  test('reset re-scans from the beginning', () {
    expect(chunker.takeCompletedSentences('Old. '), ['Old.']);
    chunker.reset();
    expect(chunker.takeCompletedSentences('New. '), ['New.']);
  });

  test('shrinking text re-scans from the start', () {
    expect(chunker.takeCompletedSentences('Reply one. more'), ['Reply one.']);
    // A fresh, shorter reply arrives (e.g. a new generation reusing the chunker
    // without reset): it should re-emit from the start, not skip content.
    expect(chunker.takeCompletedSentences('Hi. '), ['Hi.']);
  });
}
