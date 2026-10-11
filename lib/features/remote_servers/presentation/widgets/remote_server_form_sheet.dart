import 'package:flutter/material.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_protocol.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_form_field.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class RemoteServerFormSheet extends StatefulWidget {
  const RemoteServerFormSheet({
    required this.onSubmit,
    this.existing,
    super.key,
  });

  final RemoteServerEntry? existing;
  final Future<void> Function(
    String name,
    String baseUrl,
    String token,
    RemoteServerProtocol protocol,
  )
  onSubmit;

  @override
  State<RemoteServerFormSheet> createState() => _RemoteServerFormSheetState();
}

class _RemoteServerFormSheetState extends State<RemoteServerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late RemoteServerProtocol _protocol;
  bool _saving = false;
  String? _validationMessage;

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
    _protocol =
        widget.existing?.protocol ?? RemoteServerProtocol.openAiCompatible;
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
            label: 'API protocol',
            field: DropdownButtonFormField<RemoteServerProtocol>(
              initialValue: _protocol,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: RemoteServerProtocol.values
                  .map(
                    (protocol) => DropdownMenuItem(
                      value: protocol,
                      child: Text(protocol.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (protocol) {
                      if (protocol == null) return;
                      setState(() {
                        _protocol = protocol;
                        _validationMessage = null;
                        if (protocol == RemoteServerProtocol.anthropic &&
                            _urlController.text.trim().isEmpty) {
                          _urlController.text = 'https://api.anthropic.com';
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 8),
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
              hintText: _protocol == RemoteServerProtocol.anthropic
                  ? 'https://api.anthropic.com'
                  : 'http://192.168.1.30:11434',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          FieldWrapper(
            label: _protocol == RemoteServerProtocol.anthropic
                ? 'Anthropic API key'
                : 'Token (optional)',
            field: RemoteServerFormField(
              controller: _tokenController,
              hintText: _protocol == RemoteServerProtocol.anthropic
                  ? 'sk-ant-…'
                  : 'Bearer token',
              obscureText: true,
            ),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 1),
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
    if (name.isEmpty || baseUrl.isEmpty) {
      setState(() {
        _validationMessage = 'Server name and base URL are required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _validationMessage = null;
    });
    try {
      await widget.onSubmit(name, baseUrl, token, _protocol);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _validationMessage = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
