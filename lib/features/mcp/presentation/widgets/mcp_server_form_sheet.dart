import 'package:flutter/material.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_form_field.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class McpServerFormSheet extends StatefulWidget {
  const McpServerFormSheet({required this.onSubmit, this.existing, super.key});

  final McpServer? existing;
  final Future<void> Function(
    String name,
    String url,
    String authHeader,
    bool enabled,
  )
  onSubmit;

  @override
  State<McpServerFormSheet> createState() => _McpServerFormSheetState();
}

class _McpServerFormSheetState extends State<McpServerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _authController;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _authController = TextEditingController(
      text: widget.existing?.authHeader ?? '',
    );
    _enabled = widget.existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        20,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditMode ? 'Edit MCP Server' : 'Add MCP Server',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          FieldWrapper(
            label: 'Server name',
            field: RemoteServerFormField(
              controller: _nameController,
              hintText: 'My MCP server',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          FieldWrapper(
            label: 'Streamable HTTP URL',
            field: RemoteServerFormField(
              controller: _urlController,
              hintText: 'https://example.com/mcp',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          FieldWrapper(
            label: 'Auth header (optional)',
            field: RemoteServerFormField(
              controller: _authController,
              hintText: 'Bearer token',
              obscureText: true,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: _enabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: const Text('Discover this server\'s tools in chat'),
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditMode ? 'Update Server' : 'Add Server'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final auth = _authController.text.trim();
    if (name.isEmpty || url.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(name, url, auth, _enabled);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
