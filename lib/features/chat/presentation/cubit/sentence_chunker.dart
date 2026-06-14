import 'package:gena/features/chat/presentation/cubit/text_to_speak.dart';

/// Splits a *growing* reply into complete sentences so text-to-speech can start
/// speaking the first sentence while the rest of the reply is still streaming in.
///
/// The chunker is stateful: it remembers how much of the text it has already
/// emitted (the "consumed" cursor). Each call to [takeCompletedSentences] is
/// given the full text seen so far and returns only the sentences that have
/// completed since the previous call. A trailing, not-yet-terminated sentence is
/// held back until it is terminated by later text or released by [flush].
///
/// A sentence is considered complete when it ends in `.`, `!`, `?` (optionally
/// followed by closing quotes/brackets) and is followed by whitespace, or when a
/// newline terminates the line. Common abbreviations (e.g. "Dr.", "e.g.") and
/// decimal numbers (e.g. "3.14") are not treated as sentence boundaries.
///
/// Each emitted sentence is run through [stripMarkdownForSpeech] so formatting
/// markers are not read aloud; sentences that strip to empty are skipped.
class SentenceChunker {
  /// How many characters of the full text have already been emitted (or held as
  /// part of an in-progress sentence that was emitted on a prior `flush`).
  int _consumed = 0;

  /// Abbreviations that end in a period but do not end a sentence. Compared
  /// case-insensitively against the token immediately before the period.
  static const Set<String> _abbreviations = <String>{
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'st',
    'sr',
    'jr',
    'vs',
    'etc',
    'eg',
    'ie',
    'no',
    'al',
    'inc',
    'ltd',
    'co',
    'fig',
    'approx',
    'dept',
    'est',
  };

  /// Given the full reply text seen so far, returns the sentences that have
  /// completed since the last call. The trailing partial sentence (if any) is
  /// retained for a later call or [flush].
  List<String> takeCompletedSentences(String fullTextSoFar) {
    if (fullTextSoFar.length < _consumed) {
      // The text shrank (e.g. a new generation started); reset the cursor so we
      // re-scan from the beginning rather than skipping content.
      _consumed = 0;
    }

    final sentences = <String>[];
    var searchStart = _consumed;

    for (var i = _consumed; i < fullTextSoFar.length; i++) {
      final ch = fullTextSoFar[i];
      final isTerminator = ch == '.' || ch == '!' || ch == '?' || ch == '\n';
      if (!isTerminator) continue;

      // Consume any closing quotes/brackets that belong to the sentence end.
      var end = i + 1;
      if (ch != '\n') {
        while (end < fullTextSoFar.length &&
            _isClosingPunctuation(fullTextSoFar[end])) {
          end++;
        }
      }

      // A `.`/`!`/`?` only terminates if followed by whitespace or end-of-text.
      // (For end-of-text we hold the partial back — it may still be growing.)
      if (ch != '\n') {
        if (end >= fullTextSoFar.length) {
          // Reached the live end of the stream; this might still be mid-word.
          // Stop scanning and keep it as the trailing partial.
          break;
        }
        if (!_isWhitespace(fullTextSoFar[end])) {
          continue;
        }
        if (ch == '.' && _looksLikeAbbreviationOrNumber(fullTextSoFar, i)) {
          continue;
        }
      }

      final raw = fullTextSoFar.substring(searchStart, end);
      final spoken = stripMarkdownForSpeech(raw);
      if (spoken.isNotEmpty) {
        sentences.add(spoken);
      }
      searchStart = end;
      _consumed = end;
      i = end - 1; // resume after the boundary (loop will ++)
    }

    return sentences;
  }

  /// Releases the remaining trailing text as a final sentence (used when
  /// generation completes). Returns the stripped remainder, or an empty list if
  /// nothing is left.
  List<String> flush(String fullText) {
    if (fullText.length < _consumed) {
      _consumed = 0;
    }
    if (_consumed >= fullText.length) return const <String>[];
    final remainder = fullText.substring(_consumed);
    _consumed = fullText.length;
    final spoken = stripMarkdownForSpeech(remainder);
    if (spoken.isEmpty) return const <String>[];
    return <String>[spoken];
  }

  /// Resets the chunker so it can be reused for a fresh reply.
  void reset() {
    _consumed = 0;
  }

  bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';

  bool _isClosingPunctuation(String ch) =>
      ch == '"' ||
      ch == "'" ||
      ch == ')' ||
      ch == ']' ||
      ch == '}' ||
      ch == '”' ||
      ch == '’';

  /// Whether the `.` at [dotIndex] is part of an abbreviation or a decimal
  /// number rather than a sentence terminator.
  bool _looksLikeAbbreviationOrNumber(String text, int dotIndex) {
    // Decimal number: digit immediately before and after the dot (e.g. 3.14).
    if (dotIndex > 0 &&
        dotIndex + 1 < text.length &&
        _isDigit(text[dotIndex - 1]) &&
        _isDigit(text[dotIndex + 1])) {
      return true;
    }

    // Walk back over the preceding word characters to isolate the token.
    var start = dotIndex;
    while (start > 0 && _isWord(text[start - 1])) {
      start--;
    }
    if (start == dotIndex) return false;
    final token = text.substring(start, dotIndex).toLowerCase();

    // Single-letter token followed by a dot (initials like "J." or "U.S.").
    if (token.length == 1) return true;

    return _abbreviations.contains(token);
  }

  bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isWord(String ch) {
    final code = ch.codeUnitAt(0);
    final isLetter =
        (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
    return isLetter || _isDigit(ch);
  }
}
