class WorkspaceEntity {
  final String id;
  final String name;
  final String generalInstruction;
  final bool ragEnabled;
  final bool nativeToolsEnabled;
  final bool nativeOpenUrlEnabled;
  final bool nativeOpenAppEnabled;
  final bool nativeSendEmailEnabled;
  final bool nativeFlashlightEnabled;
  final DateTime createdAt;

  const WorkspaceEntity({
    required this.id,
    required this.name,
    required this.generalInstruction,
    required this.ragEnabled,
    required this.nativeToolsEnabled,
    required this.nativeOpenUrlEnabled,
    required this.nativeOpenAppEnabled,
    required this.nativeSendEmailEnabled,
    required this.nativeFlashlightEnabled,
    required this.createdAt,
  });
}
