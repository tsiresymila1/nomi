import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fullscreen_image_viewer/fullscreen_image_viewer.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:shimmer/shimmer.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.kind = 'text',
    this.mediaPath,
    this.isStreaming = false,
  });

  final String message;
  final bool isUser;
  final String kind;
  final String? mediaPath;
  final bool isStreaming;

  String get _normalizedKind => kind.trim().toLowerCase();

  bool get _isThinkingKind =>
      _normalizedKind == 'thinking' ||
      _normalizedKind == 'reasoning' ||
      _normalizedKind.contains('thinking') ||
      _normalizedKind.contains('reason');

  bool get _isToolWaitingKind =>
      _normalizedKind == 'tool_waiting' ||
      _normalizedKind == 'tool-calling' ||
      _normalizedKind.contains('tool_wait') ||
      _normalizedKind.contains('tool_call');

  bool get _isToolTraceKind =>
      _normalizedKind == 'tool_trace' ||
      _normalizedKind == 'tool-trace' ||
      _normalizedKind.contains('tool_trace') ||
      _normalizedKind.contains('trace');

  @override
  Widget build(BuildContext context) {
    final isThinking = _isThinkingKind && !isUser;
    final isTool = _isToolTraceKind || _isToolWaitingKind;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primary
        : isThinking || isTool
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.transparent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (kind == 'image' && mediaPath != null) {
      return Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.trim().isNotEmpty)
            GptMarkdown(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              FullscreenImageViewer.open(
                context: context,
                child: Image.file(File(mediaPath!)),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(mediaPath!),
                fit: BoxFit.cover,
                width: 180,
                errorBuilder: (_, _, _) => const Text('Image unavailable'),
              ),
            ),
          ),
        ],
      );
    }

    if (!isUser &&
        (_isThinkingKind || _isToolWaitingKind || _isToolTraceKind)) {
      return _buildInsightChip(context);
    }

    if (!isUser && isStreaming && message.trim().isEmpty) {
      return SizedBox(
        width: 28,
        height: 14,
        child: SpinKitThreeBounce(
          size: 6,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return GptMarkdown(message, style: TextStyle(fontSize: isUser ? 14 : 13));
  }

  Widget _buildInsightChip(BuildContext context) {
    final (title, subtitle) = switch (kind) {
      _ when _isThinkingKind => ('Reasoning', 'Tap to view details'),
      _ when _isToolWaitingKind => ('Function calling', 'Tap to view stream'),
      _ when _isToolTraceKind => ('Function trace', 'Tap to view details'),
      _ => ('Details', 'Tap to view'),
    };

    final colorScheme = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    );

    final animatedTitle = isStreaming
        ? Shimmer.fromColors(
            baseColor: colorScheme.onSurface.withValues(alpha: 0.65),
            highlightColor: colorScheme.onSurface.withValues(alpha: 0.95),
            child: titleText,
          )
        : titleText;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showInsightSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  animatedTitle,
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showInsightSheet(BuildContext context) {
    final title = switch (kind) {
      _ when _isThinkingKind => 'Reasoning',
      _ when _isToolWaitingKind => 'Function Calling',
      _ when _isToolTraceKind => 'Function Trace',
      _ => 'Details',
    };

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildInsightDetails(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightDetails(BuildContext context) {
    if (_isThinkingKind && isStreaming) {
      return BlocBuilder<ChatDraftThinkingCubit, String?>(
        bloc: sl<ChatDraftThinkingCubit>(),
        builder: (context, draft) => _buildDetailsMarkdown(draft ?? ''),
      );
    }

    if (_isToolWaitingKind && isStreaming) {
      return BlocBuilder<ChatToolWaitingCubit, String?>(
        bloc: sl<ChatToolWaitingCubit>(),
        builder: (context, waitingToolName) {
          final detail = (waitingToolName ?? '').trim().isEmpty
              ? message
              : 'Waiting for function tool: $waitingToolName';
          return _buildDetailsMarkdown(detail);
        },
      );
    }

    return _buildDetailsMarkdown(message);
  }

  Widget _buildDetailsMarkdown(String content) {
    final text = content.trim();
    if (text.isEmpty) {
      return const Center(
        child: Text('No details yet...', style: TextStyle(fontSize: 12)),
      );
    }
    return SingleChildScrollView(
      child: GptMarkdown(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
