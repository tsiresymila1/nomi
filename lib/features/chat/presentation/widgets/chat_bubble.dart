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
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

class ChatBubble extends ConsumerStatefulWidget {
  final String message;
  final bool isUser;
  final String kind;
  final String? mediaPath;
  final bool isStreaming;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.kind = 'text',
    this.mediaPath,
    this.isStreaming = false,
  });

  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  Future<void> _showMessageBottomSheet({
    required String title,
    required String message,
    required bool isDark,
    required IconData icon,
    required String kind,
    required bool isStreaming,
    double fontSize = 11,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.60;
        return SizedBox(
          height: maxHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.outlineVariant.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      String liveMessage = message;
                      if (isStreaming && kind == 'thinking') {
                        liveMessage =
                            ref.watch(chatDraftThinkingProvider) ?? message;
                      } else if (isStreaming && kind == 'tool_waiting') {
                        final waitingTool = ref.watch(chatToolWaitingProvider);
                        final toolName = waitingTool?.trim() ?? '';
                        liveMessage = toolName.isEmpty
                            ? message
                            : 'Waiting for function tool: $toolName';
                      }

                      final content = Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: MdMessage(
                            key: ValueKey(
                              'sheet-$title-$isDark-${liveMessage.hashCode}',
                            ),
                            message: liveMessage,
                            isUser: false,
                            isDark: isDark,
                            fontSize: fontSize,
                          ),
                        ),
                      );

                      if (!isStreaming) return content;

                      return Shimmer.fromColors(
                        baseColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(170),
                        highlightColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(80),
                        child: content,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    final isToolWaiting = kind == 'tool_waiting' && !isUser;
    final isToolTrace = (isToolTraceKind || isToolWaiting) && !isUser;
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
                ? InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _showMessageBottomSheet(
                        title: 'Reasoning',
                        message: message,
                        isDark: isDark,
                        icon: Icons.psychology_outlined,
                        kind: kind,
                        isStreaming: widget.isStreaming,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology_outlined, size: 16),
                          const SizedBox(width: 6),
                          _shimmerWrap(
                            enabled: widget.isStreaming,
                            child: Text(
                              'Reasoning',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                        ],
                      ),
                    ),
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
                ? InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _showMessageBottomSheet(
                        title: isToolWaiting
                            ? 'Function call'
                            : 'Function trace',
                        message: isToolWaiting
                            ? 'Waiting for function tool...'
                            : message,
                        isDark: isDark,
                        icon: Icons.settings_ethernet,
                        kind: kind,
                        isStreaming: widget.isStreaming,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.settings_ethernet, size: 14),
                          const SizedBox(width: 6),
                          _shimmerWrap(
                            enabled: widget.isStreaming,
                            child: Text(
                              isToolWaiting
                                  ? 'Function call'
                                  : 'Function trace',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                        ],
                      ),
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

  Widget _shimmerWrap({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.onSurface.withAlpha(170),
      highlightColor: Theme.of(context).colorScheme.onSurface.withAlpha(80),
      child: child,
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
