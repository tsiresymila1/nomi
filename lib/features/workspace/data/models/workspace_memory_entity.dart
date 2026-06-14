class WorkspaceMemoryEntity {
  const WorkspaceMemoryEntity({
    required this.id,
    required this.workspaceId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String workspaceId;
  final String content;
  final DateTime createdAt;
}
