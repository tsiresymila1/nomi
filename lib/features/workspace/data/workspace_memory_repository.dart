import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/workspace/data/models/workspace_memory_entity.dart';

/// CRUD access to per-workspace persistent memories stored in Drift.
///
/// Memory content is sensitive user data and is never logged here.
class WorkspaceMemoryRepository {
  WorkspaceMemoryRepository({
    required db.GenaDatabase database,
    int maxMemoriesPerWorkspace = defaultMaxMemoriesPerWorkspace,
  }) : _database = database,
       _maxMemoriesPerWorkspace = maxMemoriesPerWorkspace;

  static const int defaultMaxMemoriesPerWorkspace = 50;

  final db.GenaDatabase _database;
  final int _maxMemoriesPerWorkspace;

  int get maxMemoriesPerWorkspace => _maxMemoriesPerWorkspace;

  /// Adds [content] for [workspaceId].
  ///
  /// Deduplicates near-identical content (case-insensitive, whitespace
  /// collapsed); returns the existing memory id when a duplicate is found.
  /// Enforces a per-workspace cap by trimming the oldest entries.
  Future<WorkspaceMemoryAddResult> addMemory(
    String workspaceId,
    String content,
  ) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return const WorkspaceMemoryAddResult(
        status: WorkspaceMemoryAddStatus.invalidWorkspace,
      );
    }

    final normalized = _normalizeContent(content);
    if (normalized.isEmpty) {
      return const WorkspaceMemoryAddResult(
        status: WorkspaceMemoryAddStatus.empty,
      );
    }

    final existing = await _findByNormalizedContent(
      parsedWorkspaceId,
      normalized,
    );
    if (existing != null) {
      final count = await _countForWorkspace(parsedWorkspaceId);
      return WorkspaceMemoryAddResult(
        status: WorkspaceMemoryAddStatus.duplicate,
        memory: _mapRow(existing),
        totalCount: count,
      );
    }

    final cleaned = content.trim();
    final insertedId = await _database
        .into(_database.workspaceMemories)
        .insert(
          db.WorkspaceMemoriesCompanion.insert(
            workspace: parsedWorkspaceId,
            content: cleaned,
          ),
        );

    var trimmed = 0;
    trimmed = await _enforceCap(parsedWorkspaceId);

    final row = await (_database.select(
      _database.workspaceMemories,
    )..where((t) => t.id.equals(insertedId))).getSingleOrNull();
    final count = await _countForWorkspace(parsedWorkspaceId);

    return WorkspaceMemoryAddResult(
      status: trimmed > 0
          ? WorkspaceMemoryAddStatus.storedWithTrim
          : WorkspaceMemoryAddStatus.stored,
      memory: row == null ? null : _mapRow(row),
      totalCount: count,
      trimmedCount: trimmed,
    );
  }

  Future<List<WorkspaceMemoryEntity>> listMemories(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return const <WorkspaceMemoryEntity>[];
    final rows =
        await (_database.select(_database.workspaceMemories)
              ..where((t) => t.workspace.equals(parsedWorkspaceId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_mapRow).toList(growable: false);
  }

  Stream<List<WorkspaceMemoryEntity>> watchMemories(String workspaceId) {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return Stream<List<WorkspaceMemoryEntity>>.value(
        const <WorkspaceMemoryEntity>[],
      );
    }
    final query = _database.select(_database.workspaceMemories)
      ..where((t) => t.workspace.equals(parsedWorkspaceId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(_mapRow).toList(growable: false),
    );
  }

  Future<int> deleteMemory(int id) {
    return (_database.delete(
      _database.workspaceMemories,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Removes memories in [workspaceId] whose normalized content matches
  /// [content]. Returns the number of removed rows.
  Future<int> deleteByContent(String workspaceId, String content) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return 0;
    final normalized = _normalizeContent(content);
    if (normalized.isEmpty) return 0;

    final rows = await (_database.select(
      _database.workspaceMemories,
    )..where((t) => t.workspace.equals(parsedWorkspaceId))).get();
    final matchingIds = <int>[
      for (final row in rows)
        if (_normalizeContent(row.content) == normalized) row.id,
    ];
    if (matchingIds.isEmpty) return 0;

    return (_database.delete(
      _database.workspaceMemories,
    )..where((t) => t.id.isIn(matchingIds))).go();
  }

  Future<db.WorkspaceMemory?> _findByNormalizedContent(
    int workspaceId,
    String normalized,
  ) async {
    final rows = await (_database.select(
      _database.workspaceMemories,
    )..where((t) => t.workspace.equals(workspaceId))).get();
    for (final row in rows) {
      if (_normalizeContent(row.content) == normalized) return row;
    }
    return null;
  }

  Future<int> _countForWorkspace(int workspaceId) async {
    final rows = await (_database.select(
      _database.workspaceMemories,
    )..where((t) => t.workspace.equals(workspaceId))).get();
    return rows.length;
  }

  /// Trims the oldest memories beyond the cap. Returns the number removed.
  Future<int> _enforceCap(int workspaceId) async {
    final rows =
        await (_database.select(_database.workspaceMemories)
              ..where((t) => t.workspace.equals(workspaceId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    if (rows.length <= _maxMemoriesPerWorkspace) return 0;

    final excessIds = rows
        .skip(_maxMemoriesPerWorkspace)
        .map((row) => row.id)
        .toList(growable: false);
    await (_database.delete(
      _database.workspaceMemories,
    )..where((t) => t.id.isIn(excessIds))).go();
    return excessIds.length;
  }

  String _normalizeContent(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  WorkspaceMemoryEntity _mapRow(db.WorkspaceMemory row) {
    return WorkspaceMemoryEntity(
      id: row.id,
      workspaceId: row.workspace.toString(),
      content: row.content,
      createdAt: row.createdAt,
    );
  }
}

enum WorkspaceMemoryAddStatus {
  stored,
  storedWithTrim,
  duplicate,
  empty,
  invalidWorkspace,
}

class WorkspaceMemoryAddResult {
  const WorkspaceMemoryAddResult({
    required this.status,
    this.memory,
    this.totalCount = 0,
    this.trimmedCount = 0,
  });

  final WorkspaceMemoryAddStatus status;
  final WorkspaceMemoryEntity? memory;
  final int totalCount;
  final int trimmedCount;
}
