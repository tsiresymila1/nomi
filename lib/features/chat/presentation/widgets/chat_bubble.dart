import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/setting/data/theme_settings_provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ChatBubble extends ConsumerWidget {
  final String message;
  final bool isUser;

  const ChatBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context, ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.green[700]
              : isDark
              ? Colors.grey[900]?.withAlpha(100)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: GptMarkdown(
          message,
          style: TextStyle(
            color: isUser ? Colors.white : null,
            fontSize: 14,
            height: 1.4,
          ),
          textAlign: isUser ? TextAlign.right : TextAlign.left,
          followLinkColor: true,
          codeBuilder: (context, name, code, closed) {
            Widget buildCodeContent(Widget child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
              );
            }

            if (!closed) {
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade900),
                  child: Text(
                    code,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),

              );
            }
            return buildCodeContent(
              SizedBox(
                width: 1000,
                child: HighlightView(
                  code,
                  language: name,
                  theme: isDark ? darkTheme : githubTheme,
                  padding: const EdgeInsets.all(12),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
