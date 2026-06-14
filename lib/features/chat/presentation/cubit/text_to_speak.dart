/// Shared helper that converts markdown-formatted assistant text into plain
/// spoken text. Used by both [VoiceOutputCubit] (per-message read-aloud) and the
/// hands-free [VoiceConversationCubit] so the two flows strip formatting
/// identically and the logic lives in one place.
///
/// Collapses common `gpt_markdown`-style formatting into plain text so the TTS
/// engine does not read markers (`**`, backticks, `#`, links, etc.) aloud.
String stripMarkdownForSpeech(String input) {
  var text = input;

  // Fenced code blocks -> keep the inner code, drop the fences and lang tag.
  text = text.replaceAllMapped(
    RegExp(r'```[^\n]*\n([\s\S]*?)```', multiLine: true),
    (m) => m.group(1) ?? '',
  );

  // Images ![alt](url) -> alt; links [text](url) -> text.
  text = text.replaceAllMapped(
    RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );

  // Inline code, bold/italic/strikethrough markers.
  text = text.replaceAll('`', '');
  text = text.replaceAll(RegExp(r'(\*\*\*|\*\*|\*|___|__|_|~~)'), '');

  // Leading block markers per line: headings (#), blockquotes (>), list
  // bullets (-, *, +) and ordered list numbers.
  text = text
      .split('\n')
      .map(
        (line) => line.replaceFirst(
          RegExp(r'^\s*(#{1,6}\s+|>\s?|[-*+]\s+|\d+[.)]\s+)'),
          '',
        ),
      )
      .join('\n');

  // Collapse excess whitespace.
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r'\n{2,}'), '\n');

  return text.trim();
}
