import 'package:flutter/material.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_form_field.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class RemoteServerFormSheet extends StatefulWidget {
  const RemoteServerFormSheet({
    required this.onSubmit,
    this.existing,
    super.key,
  });

  final RemoteServerEntry? existing;
  final Future<void> Function(String name, String baseUrl, String token)
  onSubmit;

  @override
  State<RemoteServerFormSheet> createState() => _RemoteServerFormSheetState();
}

class _RemoteServerFormSheetState extends State<RemoteServerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _urlController = TextEditingController(
      text: widget.existing?.baseUrl ?? '',
    );
    _tokenController = TextEditingController(
      text: widget.existing?.token ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
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
            isEditMode ? 'Edit Remote Server' : 'Add Remote Server',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          FieldWrapper(
            label: 'Server name',
            field: RemoteServerFormField(
              controller: _nameController,
              hintText: 'My remote server',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          FieldWrapper(
            label: 'Base URL',
            field: RemoteServerFormField(
              controller: _urlController,
              hintText: 'http://192.168.1.30:11434',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          FieldWrapper(
            label: 'Token (optional)',
            field: RemoteServerFormField(
              controller: _tokenController,
              hintText: 'Bearer token',
              obscureText: true,
            ),
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
    final baseUrl = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (name.isEmpty || baseUrl.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(name, baseUrl, token);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
