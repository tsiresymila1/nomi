import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/setting/data/providers/theme_settings_provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ChatBubble extends ConsumerWidget {
  final String message;
  final bool isUser;
  final String kind;
  final String? mediaPath;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.kind = 'text',
    this.mediaPath,
  });

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
              ? Colors.grey[800]?.withAlpha(100)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child:  (kind == 'image' && mediaPath != null)  ?
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isUser ? CrossAxisAlignment.end: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  if(message.isNotEmpty)  MdMessage(message: message, isUser: isUser, isDark: isDark),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(mediaPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: Text('Image unavailable')),
                        );
                      },
                    ),
                  ),
                ],
              )
           :
              MdMessage(message: message, isUser: isUser, isDark: isDark),
      ),
    );
  }
}

class MdMessage extends StatelessWidget {
  const MdMessage({
    super.key,
    required this.message,
    required this.isUser,
    required this.isDark,
  });

  final String message;
  final bool isUser;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      message,
      style: TextStyle(
        color: isUser ? Colors.white : null,
        fontSize: 14,
        height: 1.4,
      ),
      textAlign:TextAlign.left,
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
              theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}
