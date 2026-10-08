import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class WorkspacePromptEditorPage extends StatefulWidget {
  const WorkspacePromptEditorPage({super.key, required this.initialPrompt});

  final String initialPrompt;

  @override
  State<WorkspacePromptEditorPage> createState() =>
      _WorkspacePromptEditorPageState();
}

class _WorkspacePromptEditorPageState extends State<WorkspacePromptEditorPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showPreview = false;
  bool _allowPop = false;

  bool get _hasChanges => _controller.text != widget.initialPrompt;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt)
      ..addListener(_refresh);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _save() => _popWithResult(_controller.text);

  void _popWithResult(String? result) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _requestClose() async {
    if (!_hasChanges) {
      context.pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard prompt changes?'),
        content: const Text('Your Markdown prompt has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _popWithResult(null);
  }

  void _wrapSelection(String marker, {String placeholder = 'text'}) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final selected = start == end
        ? placeholder
        : _controller.text.substring(start, end);
    final replacement = '$marker$selected$marker';
    _controller.value = _controller.value.copyWith(
      text: _controller.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + marker.length,
        extentOffset: start + marker.length + selected.length,
      ),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _insertLinePrefix(String prefix, {String placeholder = 'Instruction'}) {
    final selection = _controller.selection;
    final offset = selection.isValid
        ? selection.start
        : _controller.text.length;
    final lineStart = _controller.text.lastIndexOf('\n', offset - 1) + 1;
    final insert = '$prefix$placeholder';
    _controller.value = _controller.value.copyWith(
      text: _controller.text.replaceRange(lineStart, lineStart, insert),
      selection: TextSelection.collapsed(offset: lineStart + insert.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _requestClose),
          title: const Text('Prompt editor'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 840;
            return Column(
              children: [
                if (!sideBySide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.edit_note_rounded),
                            label: Text('Edit'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.visibility_outlined),
                            label: Text('Preview'),
                          ),
                        ],
                        selected: {_showPreview},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) {
                          setState(() => _showPreview = value.first);
                        },
                      ),
                    ),
                  ),
                Expanded(
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildEditor()),
                            const VerticalDivider(width: 1),
                            Expanded(child: _buildPreview()),
                          ],
                        )
                      : _showPreview
                      ? _buildPreview()
                      : _buildEditor(),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_controller.text.characters.length} characters',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Apply prompt'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MarkdownToolbar(
            onHeading: () => _insertLinePrefix('## '),
            onBold: () => _wrapSelection('**'),
            onItalic: () => _wrapSelection('_'),
            onList: () => _insertLinePrefix('- '),
            onCode: () => _wrapSelection('`', placeholder: 'code'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('workspace-prompt-editor-field'),
              controller: _controller,
              focusNode: _focusNode,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: 'Write the workspace system prompt in Markdown…',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final prompt = _controller.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: prompt.isEmpty
          ? Center(
              child: Text(
                'Nothing to preview yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : GptMarkdown(prompt),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onList,
    required this.onCode,
  });

  final VoidCallback onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onList;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onHeading,
              tooltip: 'Heading',
              icon: const Icon(Icons.title_rounded),
            ),
            IconButton(
              onPressed: onBold,
              tooltip: 'Bold',
              icon: const Icon(Icons.format_bold_rounded),
            ),
            IconButton(
              onPressed: onItalic,
              tooltip: 'Italic',
              icon: const Icon(Icons.format_italic_rounded),
            ),
            IconButton(
              onPressed: onList,
              tooltip: 'Bulleted list',
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
            IconButton(
              onPressed: onCode,
              tooltip: 'Inline code',
              icon: const Icon(Icons.code_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
