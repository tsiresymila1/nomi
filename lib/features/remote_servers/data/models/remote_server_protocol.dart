enum RemoteServerProtocol {
  openAiCompatible(
    storageValue: 'openai-compatible',
    label: 'OpenAI Compatible',
    modelSourceType: 'remote',
  ),
  anthropic(
    storageValue: 'anthropic',
    label: 'Anthropic',
    modelSourceType: 'remote-anthropic',
  );

  const RemoteServerProtocol({
    required this.storageValue,
    required this.label,
    required this.modelSourceType,
  });

  final String storageValue;
  final String label;
  final String modelSourceType;

  static RemoteServerProtocol fromStorageValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return RemoteServerProtocol.values.firstWhere(
      (protocol) => protocol.storageValue == normalized,
      orElse: () => RemoteServerProtocol.openAiCompatible,
    );
  }
}
