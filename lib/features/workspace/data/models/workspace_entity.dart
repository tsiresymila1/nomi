class WorkspaceEntity {
  final String id;
  final String name;
  final String generalInstruction;
  final DateTime createdAt;

  const WorkspaceEntity({
    required this.id,
    required this.name,
    required this.generalInstruction,
    required this.createdAt,
  });
}
