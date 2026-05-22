class WorkspaceEntity {
  final String id;
  final String name;
  final String generalInstruction;
  final bool ragEnabled;
  final DateTime createdAt;

  const WorkspaceEntity({
    required this.id,
    required this.name,
    required this.generalInstruction,
    required this.ragEnabled,
    required this.createdAt,
  });
}
