class NativeToolRequest {
  final String id;
  final String toolName;
  final Map<String, dynamic> args;
  final bool needApproval;
  final DateTime createdAt;

  const NativeToolRequest({
    required this.id,
    required this.toolName,
    required this.args,
    required this.needApproval,
    required this.createdAt,
  });
}
