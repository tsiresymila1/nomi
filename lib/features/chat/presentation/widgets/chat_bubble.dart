import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fullscreen_image_viewer/fullscreen_image_viewer.dart';
import 'package:gena/core/extension.dart';
import 'package:gena/core/utils.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatBubble extends ConsumerStatefulWidget {
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
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  bool _isThinkingExpanded = false;
  bool _isToolTraceExpanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = widget.isUser;
    final kind = widget.kind;
    final mediaPath = widget.mediaPath;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isThinking = kind == 'thinking' && !isUser;
    final isToolTraceKind =
        kind == 'tool_trace' || kind == 'tool_call' || kind == 'tool_result';
    final isToolTrace = isToolTraceKind && !isUser;
    return Column(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: isToolTrace || isToolTraceKind || isThinking
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: isUser
                  ? MediaQuery.of(context).size.width * 0.80
                  : MediaQuery.of(context).size.width,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.green[900]
                  : isThinking
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                        .withAlpha(isDark ? 20 : 170)
                  : isToolTrace
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                        .withAlpha(isDark ? 30 : 140)
                  : Colors.transparent,
              border: null,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
            ),
            child: isThinking
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isThinkingExpanded = !_isThinkingExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.psychology_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Reasoning',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Icon(
                                _isThinkingExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: _isThinkingExpanded
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 100,
                                    ),
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        child: MdMessage(
                                          fontSize: 11,
                                          key: const ValueKey(
                                            'thinking-expanded-content',
                                          ),
                                          message: message,
                                          isUser: false,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  )
                : (kind == 'image' && mediaPath != null)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
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
                      InkWell(
                        onTap: () {
                          FullscreenImageViewer.open(
                            context: context,
                            child: Hero(
                              tag: 'md-image-$isDark-${message.hashCode}',
                              child: Image.file(File(mediaPath)),
                            ).animate().fade(duration: 300.ms),
                            closeWidget: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(mediaPath),
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
                      ),
                    ],
                  )
                : isToolTrace
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _isToolTraceExpanded = !_isToolTraceExpanded;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.settings_ethernet, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Function trace',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _isToolTraceExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            child: _isToolTraceExpanded
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: MdMessage(
                                      key: ValueKey(
                                        'md-tool-$isDark-${message.hashCode}',
                                      ),
                                      message: message,
                                      isUser: false,
                                      isDark: isDark,
                                      fontSize: 11,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  )
                : MdMessage(
                    key: ValueKey('md-$isDark-${message.hashCode}'),
                    message: message,
                    isUser: isUser,
                    isDark: isDark,
                  ),
          ),
        ),
        if (!isUser && !isThinking && !isToolTrace && isToolTraceKind)
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
    this.fontSize = 14,
  });

  final String message;
  final bool isUser;
  final bool isDark;
  final double fontSize;

  Widget buildCodeContent(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: isUser ? () => unawaited(copyToClipboard(message)) : null,
      child: GptMarkdown(
        message,
        style: TextStyle(
          color: isUser ? Colors.white : null,
          fontSize: fontSize,
          height: 1.4,
        ),
        textAlign: TextAlign.left,
        followLinkColor: true,
        useDollarSignsForLatex: true,
        codeBuilder: (context, name, code, closed) {
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
