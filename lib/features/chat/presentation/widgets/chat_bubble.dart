import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/extension.dart';
import 'package:gena/core/utils.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hugeicons/hugeicons.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisAlignment: isUser ? MainAxisAlignment.end: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: isUser
                  ? MediaQuery.of(context).size.width * 0.80
                  : MediaQuery.of(context).size.width,
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.green[900] : Colors.transparent,
              // : isDark
              // ? Colors.grey[800]?.withAlpha(100)
              // : Colors.grey[200],
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
            ),
            child: (kind == 'image' && mediaPath != null)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isUser? MainAxisAlignment.end: MainAxisAlignment.start,
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      if (message.isNotEmpty)
                        MdMessage(
                          key: ValueKey('md-image-$isDark-${message.hashCode}'),
                          message: message,
                          isUser: isUser,
                          isDark: isDark,
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(mediaPath!),
                          fit: BoxFit.cover,
                          width: 180,
                          height: 220,
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
                : MdMessage(
                    key: ValueKey('md-$isDark-${message.hashCode}'),
                    message: message,
                    isUser: isUser,
                    isDark: isDark,
                  ),
          ),
        ),
        if (!isUser)
          Row(
            children: [
              IconButton(
                onPressed: () => unawaited(copyToClipboard(message)),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedCopy02, size: 20),
              ),
            ],
          ),
      ],
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
    return InkWell(
      onLongPress: isUser ? () => unawaited(copyToClipboard(message)) : null,
      child: GptMarkdown(
        message,
        style: TextStyle(
          color: isUser ? Colors.white : null,
          fontSize: 14,
          height: 1.4,
        ),
        textAlign: TextAlign.left,
        followLinkColor: true,
        useDollarSignsForLatex: true,
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
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.grey.shade800.withAlpha(180)
                  : Colors.grey.shade300.withAlpha(180),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ).copyWith(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.capitalize(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCopy01,
                          size: 20,
                        ),
                        onTap: () => unawaited(copyToClipboard(code)),
                      ),
                    ],
                  ),
                ),
                buildCodeContent(
                  SizedBox(
                    child: HighlightView(
                      code,
                      language: name,
                      theme: isDark
                          ? {
                              ...a11yDarkTheme,
                              'root': TextStyle(
                                color: Color(0xffabb2bf),
                                backgroundColor: Colors.transparent,
                              ),
                            }
                          : {
                              ...a11yLightTheme,
                              'root': TextStyle(
                                color: Color(0xff383a42),
                                backgroundColor: Colors.transparent,
                              ),
                            },
                      padding: const EdgeInsets.all(12),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
