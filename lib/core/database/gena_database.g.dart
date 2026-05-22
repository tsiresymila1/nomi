// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gena_database.dart';

// ignore_for_file: type=lint
class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, Workspace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generalInstructionMeta =
      const VerificationMeta('generalInstruction');
  @override
  late final GeneratedColumn<String> generalInstruction =
      GeneratedColumn<String>(
        'general_instruction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(systemPrompt),
      );
  static const VerificationMeta _ragEnabledMeta = const VerificationMeta(
    'ragEnabled',
  );
  @override
  late final GeneratedColumn<bool> ragEnabled = GeneratedColumn<bool>(
    'rag_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rag_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _nativeToolsEnabledMeta =
      const VerificationMeta('nativeToolsEnabled');
  @override
  late final GeneratedColumn<bool> nativeToolsEnabled = GeneratedColumn<bool>(
    'native_tools_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("native_tools_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nativeOpenUrlEnabledMeta =
      const VerificationMeta('nativeOpenUrlEnabled');
  @override
  late final GeneratedColumn<bool> nativeOpenUrlEnabled = GeneratedColumn<bool>(
    'native_open_url_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("native_open_url_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nativeOpenAppEnabledMeta =
      const VerificationMeta('nativeOpenAppEnabled');
  @override
  late final GeneratedColumn<bool> nativeOpenAppEnabled = GeneratedColumn<bool>(
    'native_open_app_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("native_open_app_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nativeSendEmailEnabledMeta =
      const VerificationMeta('nativeSendEmailEnabled');
  @override
  late final GeneratedColumn<bool> nativeSendEmailEnabled =
      GeneratedColumn<bool>(
        'native_send_email_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("native_send_email_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _nativeFlashlightEnabledMeta =
      const VerificationMeta('nativeFlashlightEnabled');
  @override
  late final GeneratedColumn<bool> nativeFlashlightEnabled =
      GeneratedColumn<bool>(
        'native_flashlight_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("native_flashlight_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    name,
    generalInstruction,
    ragEnabled,
    nativeToolsEnabled,
    nativeOpenUrlEnabled,
    nativeOpenAppEnabled,
    nativeSendEmailEnabled,
    nativeFlashlightEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workspace> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('general_instruction')) {
      context.handle(
        _generalInstructionMeta,
        generalInstruction.isAcceptableOrUnknown(
          data['general_instruction']!,
          _generalInstructionMeta,
        ),
      );
    }
    if (data.containsKey('rag_enabled')) {
      context.handle(
        _ragEnabledMeta,
        ragEnabled.isAcceptableOrUnknown(data['rag_enabled']!, _ragEnabledMeta),
      );
    }
    if (data.containsKey('native_tools_enabled')) {
      context.handle(
        _nativeToolsEnabledMeta,
        nativeToolsEnabled.isAcceptableOrUnknown(
          data['native_tools_enabled']!,
          _nativeToolsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('native_open_url_enabled')) {
      context.handle(
        _nativeOpenUrlEnabledMeta,
        nativeOpenUrlEnabled.isAcceptableOrUnknown(
          data['native_open_url_enabled']!,
          _nativeOpenUrlEnabledMeta,
        ),
      );
    }
    if (data.containsKey('native_open_app_enabled')) {
      context.handle(
        _nativeOpenAppEnabledMeta,
        nativeOpenAppEnabled.isAcceptableOrUnknown(
          data['native_open_app_enabled']!,
          _nativeOpenAppEnabledMeta,
        ),
      );
    }
    if (data.containsKey('native_send_email_enabled')) {
      context.handle(
        _nativeSendEmailEnabledMeta,
        nativeSendEmailEnabled.isAcceptableOrUnknown(
          data['native_send_email_enabled']!,
          _nativeSendEmailEnabledMeta,
        ),
      );
    }
    if (data.containsKey('native_flashlight_enabled')) {
      context.handle(
        _nativeFlashlightEnabledMeta,
        nativeFlashlightEnabled.isAcceptableOrUnknown(
          data['native_flashlight_enabled']!,
          _nativeFlashlightEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workspace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workspace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      generalInstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}general_instruction'],
      )!,
      ragEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rag_enabled'],
      )!,
      nativeToolsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}native_tools_enabled'],
      )!,
      nativeOpenUrlEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}native_open_url_enabled'],
      )!,
      nativeOpenAppEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}native_open_app_enabled'],
      )!,
      nativeSendEmailEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}native_send_email_enabled'],
      )!,
      nativeFlashlightEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}native_flashlight_enabled'],
      )!,
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class Workspace extends DataClass implements Insertable<Workspace> {
  final int id;
  final DateTime createdAt;
  final String name;
  final String generalInstruction;
  final bool ragEnabled;
  final bool nativeToolsEnabled;
  final bool nativeOpenUrlEnabled;
  final bool nativeOpenAppEnabled;
  final bool nativeSendEmailEnabled;
  final bool nativeFlashlightEnabled;
  const Workspace({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.generalInstruction,
    required this.ragEnabled,
    required this.nativeToolsEnabled,
    required this.nativeOpenUrlEnabled,
    required this.nativeOpenAppEnabled,
    required this.nativeSendEmailEnabled,
    required this.nativeFlashlightEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['name'] = Variable<String>(name);
    map['general_instruction'] = Variable<String>(generalInstruction);
    map['rag_enabled'] = Variable<bool>(ragEnabled);
    map['native_tools_enabled'] = Variable<bool>(nativeToolsEnabled);
    map['native_open_url_enabled'] = Variable<bool>(nativeOpenUrlEnabled);
    map['native_open_app_enabled'] = Variable<bool>(nativeOpenAppEnabled);
    map['native_send_email_enabled'] = Variable<bool>(nativeSendEmailEnabled);
    map['native_flashlight_enabled'] = Variable<bool>(nativeFlashlightEnabled);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      name: Value(name),
      generalInstruction: Value(generalInstruction),
      ragEnabled: Value(ragEnabled),
      nativeToolsEnabled: Value(nativeToolsEnabled),
      nativeOpenUrlEnabled: Value(nativeOpenUrlEnabled),
      nativeOpenAppEnabled: Value(nativeOpenAppEnabled),
      nativeSendEmailEnabled: Value(nativeSendEmailEnabled),
      nativeFlashlightEnabled: Value(nativeFlashlightEnabled),
    );
  }

  factory Workspace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workspace(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      name: serializer.fromJson<String>(json['name']),
      generalInstruction: serializer.fromJson<String>(
        json['generalInstruction'],
      ),
      ragEnabled: serializer.fromJson<bool>(json['ragEnabled']),
      nativeToolsEnabled: serializer.fromJson<bool>(json['nativeToolsEnabled']),
      nativeOpenUrlEnabled: serializer.fromJson<bool>(
        json['nativeOpenUrlEnabled'],
      ),
      nativeOpenAppEnabled: serializer.fromJson<bool>(
        json['nativeOpenAppEnabled'],
      ),
      nativeSendEmailEnabled: serializer.fromJson<bool>(
        json['nativeSendEmailEnabled'],
      ),
      nativeFlashlightEnabled: serializer.fromJson<bool>(
        json['nativeFlashlightEnabled'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'name': serializer.toJson<String>(name),
      'generalInstruction': serializer.toJson<String>(generalInstruction),
      'ragEnabled': serializer.toJson<bool>(ragEnabled),
      'nativeToolsEnabled': serializer.toJson<bool>(nativeToolsEnabled),
      'nativeOpenUrlEnabled': serializer.toJson<bool>(nativeOpenUrlEnabled),
      'nativeOpenAppEnabled': serializer.toJson<bool>(nativeOpenAppEnabled),
      'nativeSendEmailEnabled': serializer.toJson<bool>(nativeSendEmailEnabled),
      'nativeFlashlightEnabled': serializer.toJson<bool>(
        nativeFlashlightEnabled,
      ),
    };
  }

  Workspace copyWith({
    int? id,
    DateTime? createdAt,
    String? name,
    String? generalInstruction,
    bool? ragEnabled,
    bool? nativeToolsEnabled,
    bool? nativeOpenUrlEnabled,
    bool? nativeOpenAppEnabled,
    bool? nativeSendEmailEnabled,
    bool? nativeFlashlightEnabled,
  }) => Workspace(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    name: name ?? this.name,
    generalInstruction: generalInstruction ?? this.generalInstruction,
    ragEnabled: ragEnabled ?? this.ragEnabled,
    nativeToolsEnabled: nativeToolsEnabled ?? this.nativeToolsEnabled,
    nativeOpenUrlEnabled: nativeOpenUrlEnabled ?? this.nativeOpenUrlEnabled,
    nativeOpenAppEnabled: nativeOpenAppEnabled ?? this.nativeOpenAppEnabled,
    nativeSendEmailEnabled:
        nativeSendEmailEnabled ?? this.nativeSendEmailEnabled,
    nativeFlashlightEnabled:
        nativeFlashlightEnabled ?? this.nativeFlashlightEnabled,
  );
  Workspace copyWithCompanion(WorkspacesCompanion data) {
    return Workspace(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      name: data.name.present ? data.name.value : this.name,
      generalInstruction: data.generalInstruction.present
          ? data.generalInstruction.value
          : this.generalInstruction,
      ragEnabled: data.ragEnabled.present
          ? data.ragEnabled.value
          : this.ragEnabled,
      nativeToolsEnabled: data.nativeToolsEnabled.present
          ? data.nativeToolsEnabled.value
          : this.nativeToolsEnabled,
      nativeOpenUrlEnabled: data.nativeOpenUrlEnabled.present
          ? data.nativeOpenUrlEnabled.value
          : this.nativeOpenUrlEnabled,
      nativeOpenAppEnabled: data.nativeOpenAppEnabled.present
          ? data.nativeOpenAppEnabled.value
          : this.nativeOpenAppEnabled,
      nativeSendEmailEnabled: data.nativeSendEmailEnabled.present
          ? data.nativeSendEmailEnabled.value
          : this.nativeSendEmailEnabled,
      nativeFlashlightEnabled: data.nativeFlashlightEnabled.present
          ? data.nativeFlashlightEnabled.value
          : this.nativeFlashlightEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workspace(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('generalInstruction: $generalInstruction, ')
          ..write('ragEnabled: $ragEnabled, ')
          ..write('nativeToolsEnabled: $nativeToolsEnabled, ')
          ..write('nativeOpenUrlEnabled: $nativeOpenUrlEnabled, ')
          ..write('nativeOpenAppEnabled: $nativeOpenAppEnabled, ')
          ..write('nativeSendEmailEnabled: $nativeSendEmailEnabled, ')
          ..write('nativeFlashlightEnabled: $nativeFlashlightEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    name,
    generalInstruction,
    ragEnabled,
    nativeToolsEnabled,
    nativeOpenUrlEnabled,
    nativeOpenAppEnabled,
    nativeSendEmailEnabled,
    nativeFlashlightEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.name == this.name &&
          other.generalInstruction == this.generalInstruction &&
          other.ragEnabled == this.ragEnabled &&
          other.nativeToolsEnabled == this.nativeToolsEnabled &&
          other.nativeOpenUrlEnabled == this.nativeOpenUrlEnabled &&
          other.nativeOpenAppEnabled == this.nativeOpenAppEnabled &&
          other.nativeSendEmailEnabled == this.nativeSendEmailEnabled &&
          other.nativeFlashlightEnabled == this.nativeFlashlightEnabled);
}

class WorkspacesCompanion extends UpdateCompanion<Workspace> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> name;
  final Value<String> generalInstruction;
  final Value<bool> ragEnabled;
  final Value<bool> nativeToolsEnabled;
  final Value<bool> nativeOpenUrlEnabled;
  final Value<bool> nativeOpenAppEnabled;
  final Value<bool> nativeSendEmailEnabled;
  final Value<bool> nativeFlashlightEnabled;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.name = const Value.absent(),
    this.generalInstruction = const Value.absent(),
    this.ragEnabled = const Value.absent(),
    this.nativeToolsEnabled = const Value.absent(),
    this.nativeOpenUrlEnabled = const Value.absent(),
    this.nativeOpenAppEnabled = const Value.absent(),
    this.nativeSendEmailEnabled = const Value.absent(),
    this.nativeFlashlightEnabled = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String name,
    this.generalInstruction = const Value.absent(),
    this.ragEnabled = const Value.absent(),
    this.nativeToolsEnabled = const Value.absent(),
    this.nativeOpenUrlEnabled = const Value.absent(),
    this.nativeOpenAppEnabled = const Value.absent(),
    this.nativeSendEmailEnabled = const Value.absent(),
    this.nativeFlashlightEnabled = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Workspace> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? name,
    Expression<String>? generalInstruction,
    Expression<bool>? ragEnabled,
    Expression<bool>? nativeToolsEnabled,
    Expression<bool>? nativeOpenUrlEnabled,
    Expression<bool>? nativeOpenAppEnabled,
    Expression<bool>? nativeSendEmailEnabled,
    Expression<bool>? nativeFlashlightEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (name != null) 'name': name,
      if (generalInstruction != null) 'general_instruction': generalInstruction,
      if (ragEnabled != null) 'rag_enabled': ragEnabled,
      if (nativeToolsEnabled != null)
        'native_tools_enabled': nativeToolsEnabled,
      if (nativeOpenUrlEnabled != null)
        'native_open_url_enabled': nativeOpenUrlEnabled,
      if (nativeOpenAppEnabled != null)
        'native_open_app_enabled': nativeOpenAppEnabled,
      if (nativeSendEmailEnabled != null)
        'native_send_email_enabled': nativeSendEmailEnabled,
      if (nativeFlashlightEnabled != null)
        'native_flashlight_enabled': nativeFlashlightEnabled,
    });
  }

  WorkspacesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? name,
    Value<String>? generalInstruction,
    Value<bool>? ragEnabled,
    Value<bool>? nativeToolsEnabled,
    Value<bool>? nativeOpenUrlEnabled,
    Value<bool>? nativeOpenAppEnabled,
    Value<bool>? nativeSendEmailEnabled,
    Value<bool>? nativeFlashlightEnabled,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      generalInstruction: generalInstruction ?? this.generalInstruction,
      ragEnabled: ragEnabled ?? this.ragEnabled,
      nativeToolsEnabled: nativeToolsEnabled ?? this.nativeToolsEnabled,
      nativeOpenUrlEnabled: nativeOpenUrlEnabled ?? this.nativeOpenUrlEnabled,
      nativeOpenAppEnabled: nativeOpenAppEnabled ?? this.nativeOpenAppEnabled,
      nativeSendEmailEnabled:
          nativeSendEmailEnabled ?? this.nativeSendEmailEnabled,
      nativeFlashlightEnabled:
          nativeFlashlightEnabled ?? this.nativeFlashlightEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (generalInstruction.present) {
      map['general_instruction'] = Variable<String>(generalInstruction.value);
    }
    if (ragEnabled.present) {
      map['rag_enabled'] = Variable<bool>(ragEnabled.value);
    }
    if (nativeToolsEnabled.present) {
      map['native_tools_enabled'] = Variable<bool>(nativeToolsEnabled.value);
    }
    if (nativeOpenUrlEnabled.present) {
      map['native_open_url_enabled'] = Variable<bool>(
        nativeOpenUrlEnabled.value,
      );
    }
    if (nativeOpenAppEnabled.present) {
      map['native_open_app_enabled'] = Variable<bool>(
        nativeOpenAppEnabled.value,
      );
    }
    if (nativeSendEmailEnabled.present) {
      map['native_send_email_enabled'] = Variable<bool>(
        nativeSendEmailEnabled.value,
      );
    }
    if (nativeFlashlightEnabled.present) {
      map['native_flashlight_enabled'] = Variable<bool>(
        nativeFlashlightEnabled.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('generalInstruction: $generalInstruction, ')
          ..write('ragEnabled: $ragEnabled, ')
          ..write('nativeToolsEnabled: $nativeToolsEnabled, ')
          ..write('nativeOpenUrlEnabled: $nativeOpenUrlEnabled, ')
          ..write('nativeOpenAppEnabled: $nativeOpenAppEnabled, ')
          ..write('nativeSendEmailEnabled: $nativeSendEmailEnabled, ')
          ..write('nativeFlashlightEnabled: $nativeFlashlightEnabled')
          ..write(')'))
        .toString();
  }
}

class $WorkspaceDocumentsTable extends WorkspaceDocuments
    with TableInfo<$WorkspaceDocumentsTable, WorkspaceDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _workspaceMeta = const VerificationMeta(
    'workspace',
  );
  @override
  late final GeneratedColumn<int> workspace = GeneratedColumn<int>(
    'workspace',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workspaces (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ingestionStatusMeta = const VerificationMeta(
    'ingestionStatus',
  );
  @override
  late final GeneratedColumn<String> ingestionStatus = GeneratedColumn<String>(
    'ingestion_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ready'),
  );
  static const VerificationMeta _ingestionErrorMeta = const VerificationMeta(
    'ingestionError',
  );
  @override
  late final GeneratedColumn<String> ingestionError = GeneratedColumn<String>(
    'ingestion_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chunkCountMeta = const VerificationMeta(
    'chunkCount',
  );
  @override
  late final GeneratedColumn<int> chunkCount = GeneratedColumn<int>(
    'chunk_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    workspace,
    name,
    sourceType,
    sourcePath,
    content,
    ingestionStatus,
    ingestionError,
    chunkCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('workspace')) {
      context.handle(
        _workspaceMeta,
        workspace.isAcceptableOrUnknown(data['workspace']!, _workspaceMeta),
      );
    } else if (isInserting) {
      context.missing(_workspaceMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('ingestion_status')) {
      context.handle(
        _ingestionStatusMeta,
        ingestionStatus.isAcceptableOrUnknown(
          data['ingestion_status']!,
          _ingestionStatusMeta,
        ),
      );
    }
    if (data.containsKey('ingestion_error')) {
      context.handle(
        _ingestionErrorMeta,
        ingestionError.isAcceptableOrUnknown(
          data['ingestion_error']!,
          _ingestionErrorMeta,
        ),
      );
    }
    if (data.containsKey('chunk_count')) {
      context.handle(
        _chunkCountMeta,
        chunkCount.isAcceptableOrUnknown(data['chunk_count']!, _chunkCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      workspace: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workspace'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      ingestionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingestion_status'],
      )!,
      ingestionError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingestion_error'],
      ),
      chunkCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_count'],
      )!,
    );
  }

  @override
  $WorkspaceDocumentsTable createAlias(String alias) {
    return $WorkspaceDocumentsTable(attachedDatabase, alias);
  }
}

class WorkspaceDocument extends DataClass
    implements Insertable<WorkspaceDocument> {
  final int id;
  final DateTime createdAt;
  final int workspace;
  final String name;
  final String sourceType;
  final String sourcePath;
  final String content;
  final String ingestionStatus;
  final String? ingestionError;
  final int chunkCount;
  const WorkspaceDocument({
    required this.id,
    required this.createdAt,
    required this.workspace,
    required this.name,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
    required this.ingestionStatus,
    this.ingestionError,
    required this.chunkCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['workspace'] = Variable<int>(workspace);
    map['name'] = Variable<String>(name);
    map['source_type'] = Variable<String>(sourceType);
    map['source_path'] = Variable<String>(sourcePath);
    map['content'] = Variable<String>(content);
    map['ingestion_status'] = Variable<String>(ingestionStatus);
    if (!nullToAbsent || ingestionError != null) {
      map['ingestion_error'] = Variable<String>(ingestionError);
    }
    map['chunk_count'] = Variable<int>(chunkCount);
    return map;
  }

  WorkspaceDocumentsCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceDocumentsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      workspace: Value(workspace),
      name: Value(name),
      sourceType: Value(sourceType),
      sourcePath: Value(sourcePath),
      content: Value(content),
      ingestionStatus: Value(ingestionStatus),
      ingestionError: ingestionError == null && nullToAbsent
          ? const Value.absent()
          : Value(ingestionError),
      chunkCount: Value(chunkCount),
    );
  }

  factory WorkspaceDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceDocument(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      workspace: serializer.fromJson<int>(json['workspace']),
      name: serializer.fromJson<String>(json['name']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      content: serializer.fromJson<String>(json['content']),
      ingestionStatus: serializer.fromJson<String>(json['ingestionStatus']),
      ingestionError: serializer.fromJson<String?>(json['ingestionError']),
      chunkCount: serializer.fromJson<int>(json['chunkCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'workspace': serializer.toJson<int>(workspace),
      'name': serializer.toJson<String>(name),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'content': serializer.toJson<String>(content),
      'ingestionStatus': serializer.toJson<String>(ingestionStatus),
      'ingestionError': serializer.toJson<String?>(ingestionError),
      'chunkCount': serializer.toJson<int>(chunkCount),
    };
  }

  WorkspaceDocument copyWith({
    int? id,
    DateTime? createdAt,
    int? workspace,
    String? name,
    String? sourceType,
    String? sourcePath,
    String? content,
    String? ingestionStatus,
    Value<String?> ingestionError = const Value.absent(),
    int? chunkCount,
  }) => WorkspaceDocument(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    workspace: workspace ?? this.workspace,
    name: name ?? this.name,
    sourceType: sourceType ?? this.sourceType,
    sourcePath: sourcePath ?? this.sourcePath,
    content: content ?? this.content,
    ingestionStatus: ingestionStatus ?? this.ingestionStatus,
    ingestionError: ingestionError.present
        ? ingestionError.value
        : this.ingestionError,
    chunkCount: chunkCount ?? this.chunkCount,
  );
  WorkspaceDocument copyWithCompanion(WorkspaceDocumentsCompanion data) {
    return WorkspaceDocument(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      workspace: data.workspace.present ? data.workspace.value : this.workspace,
      name: data.name.present ? data.name.value : this.name,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      content: data.content.present ? data.content.value : this.content,
      ingestionStatus: data.ingestionStatus.present
          ? data.ingestionStatus.value
          : this.ingestionStatus,
      ingestionError: data.ingestionError.present
          ? data.ingestionError.value
          : this.ingestionError,
      chunkCount: data.chunkCount.present
          ? data.chunkCount.value
          : this.chunkCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceDocument(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('workspace: $workspace, ')
          ..write('name: $name, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('content: $content, ')
          ..write('ingestionStatus: $ingestionStatus, ')
          ..write('ingestionError: $ingestionError, ')
          ..write('chunkCount: $chunkCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    workspace,
    name,
    sourceType,
    sourcePath,
    content,
    ingestionStatus,
    ingestionError,
    chunkCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceDocument &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.workspace == this.workspace &&
          other.name == this.name &&
          other.sourceType == this.sourceType &&
          other.sourcePath == this.sourcePath &&
          other.content == this.content &&
          other.ingestionStatus == this.ingestionStatus &&
          other.ingestionError == this.ingestionError &&
          other.chunkCount == this.chunkCount);
}

class WorkspaceDocumentsCompanion extends UpdateCompanion<WorkspaceDocument> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<int> workspace;
  final Value<String> name;
  final Value<String> sourceType;
  final Value<String> sourcePath;
  final Value<String> content;
  final Value<String> ingestionStatus;
  final Value<String?> ingestionError;
  final Value<int> chunkCount;
  const WorkspaceDocumentsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.workspace = const Value.absent(),
    this.name = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.content = const Value.absent(),
    this.ingestionStatus = const Value.absent(),
    this.ingestionError = const Value.absent(),
    this.chunkCount = const Value.absent(),
  });
  WorkspaceDocumentsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required int workspace,
    required String name,
    required String sourceType,
    required String sourcePath,
    required String content,
    this.ingestionStatus = const Value.absent(),
    this.ingestionError = const Value.absent(),
    this.chunkCount = const Value.absent(),
  }) : workspace = Value(workspace),
       name = Value(name),
       sourceType = Value(sourceType),
       sourcePath = Value(sourcePath),
       content = Value(content);
  static Insertable<WorkspaceDocument> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<int>? workspace,
    Expression<String>? name,
    Expression<String>? sourceType,
    Expression<String>? sourcePath,
    Expression<String>? content,
    Expression<String>? ingestionStatus,
    Expression<String>? ingestionError,
    Expression<int>? chunkCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (workspace != null) 'workspace': workspace,
      if (name != null) 'name': name,
      if (sourceType != null) 'source_type': sourceType,
      if (sourcePath != null) 'source_path': sourcePath,
      if (content != null) 'content': content,
      if (ingestionStatus != null) 'ingestion_status': ingestionStatus,
      if (ingestionError != null) 'ingestion_error': ingestionError,
      if (chunkCount != null) 'chunk_count': chunkCount,
    });
  }

  WorkspaceDocumentsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<int>? workspace,
    Value<String>? name,
    Value<String>? sourceType,
    Value<String>? sourcePath,
    Value<String>? content,
    Value<String>? ingestionStatus,
    Value<String?>? ingestionError,
    Value<int>? chunkCount,
  }) {
    return WorkspaceDocumentsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      workspace: workspace ?? this.workspace,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      sourcePath: sourcePath ?? this.sourcePath,
      content: content ?? this.content,
      ingestionStatus: ingestionStatus ?? this.ingestionStatus,
      ingestionError: ingestionError ?? this.ingestionError,
      chunkCount: chunkCount ?? this.chunkCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (workspace.present) {
      map['workspace'] = Variable<int>(workspace.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (ingestionStatus.present) {
      map['ingestion_status'] = Variable<String>(ingestionStatus.value);
    }
    if (ingestionError.present) {
      map['ingestion_error'] = Variable<String>(ingestionError.value);
    }
    if (chunkCount.present) {
      map['chunk_count'] = Variable<int>(chunkCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('workspace: $workspace, ')
          ..write('name: $name, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('content: $content, ')
          ..write('ingestionStatus: $ingestionStatus, ')
          ..write('ingestionError: $ingestionError, ')
          ..write('chunkCount: $chunkCount')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, Chat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _workspaceMeta = const VerificationMeta(
    'workspace',
  );
  @override
  late final GeneratedColumn<int> workspace = GeneratedColumn<int>(
    'workspace',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workspaces (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 6,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, workspace, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('workspace')) {
      context.handle(
        _workspaceMeta,
        workspace.isAcceptableOrUnknown(data['workspace']!, _workspaceMeta),
      );
    } else if (isInserting) {
      context.missing(_workspaceMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      workspace: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workspace'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class Chat extends DataClass implements Insertable<Chat> {
  final int id;
  final DateTime createdAt;
  final int workspace;
  final String title;
  const Chat({
    required this.id,
    required this.createdAt,
    required this.workspace,
    required this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['workspace'] = Variable<int>(workspace);
    map['title'] = Variable<String>(title);
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      workspace: Value(workspace),
      title: Value(title),
    );
  }

  factory Chat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chat(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      workspace: serializer.fromJson<int>(json['workspace']),
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'workspace': serializer.toJson<int>(workspace),
      'title': serializer.toJson<String>(title),
    };
  }

  Chat copyWith({
    int? id,
    DateTime? createdAt,
    int? workspace,
    String? title,
  }) => Chat(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    workspace: workspace ?? this.workspace,
    title: title ?? this.title,
  );
  Chat copyWithCompanion(ChatsCompanion data) {
    return Chat(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      workspace: data.workspace.present ? data.workspace.value : this.workspace,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chat(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('workspace: $workspace, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, workspace, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.workspace == this.workspace &&
          other.title == this.title);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<int> workspace;
  final Value<String> title;
  const ChatsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.workspace = const Value.absent(),
    this.title = const Value.absent(),
  });
  ChatsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required int workspace,
    required String title,
  }) : workspace = Value(workspace),
       title = Value(title);
  static Insertable<Chat> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<int>? workspace,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (workspace != null) 'workspace': workspace,
      if (title != null) 'title': title,
    });
  }

  ChatsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<int>? workspace,
    Value<String>? title,
  }) {
    return ChatsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      workspace: workspace ?? this.workspace,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (workspace.present) {
      map['workspace'] = Variable<int>(workspace.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('workspace: $workspace, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _chatMeta = const VerificationMeta('chat');
  @override
  late final GeneratedColumn<int> chat = GeneratedColumn<int>(
    'chat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chats (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaPathMeta = const VerificationMeta(
    'mediaPath',
  );
  @override
  late final GeneratedColumn<String> mediaPath = GeneratedColumn<String>(
    'media_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    chat,
    role,
    kind,
    content,
    mediaPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('chat')) {
      context.handle(
        _chatMeta,
        chat.isAcceptableOrUnknown(data['chat']!, _chatMeta),
      );
    } else if (isInserting) {
      context.missing(_chatMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('media_path')) {
      context.handle(
        _mediaPathMeta,
        mediaPath.isAcceptableOrUnknown(data['media_path']!, _mediaPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      chat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      mediaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_path'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final DateTime createdAt;
  final int chat;
  final String role;
  final String kind;
  final String content;
  final String? mediaPath;
  const Message({
    required this.id,
    required this.createdAt,
    required this.chat,
    required this.role,
    required this.kind,
    required this.content,
    this.mediaPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['chat'] = Variable<int>(chat);
    map['role'] = Variable<String>(role);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || mediaPath != null) {
      map['media_path'] = Variable<String>(mediaPath);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      chat: Value(chat),
      role: Value(role),
      kind: Value(kind),
      content: Value(content),
      mediaPath: mediaPath == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaPath),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      chat: serializer.fromJson<int>(json['chat']),
      role: serializer.fromJson<String>(json['role']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      mediaPath: serializer.fromJson<String?>(json['mediaPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'chat': serializer.toJson<int>(chat),
      'role': serializer.toJson<String>(role),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'mediaPath': serializer.toJson<String?>(mediaPath),
    };
  }

  Message copyWith({
    int? id,
    DateTime? createdAt,
    int? chat,
    String? role,
    String? kind,
    String? content,
    Value<String?> mediaPath = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    chat: chat ?? this.chat,
    role: role ?? this.role,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    mediaPath: mediaPath.present ? mediaPath.value : this.mediaPath,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      chat: data.chat.present ? data.chat.value : this.chat,
      role: data.role.present ? data.role.value : this.role,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      mediaPath: data.mediaPath.present ? data.mediaPath.value : this.mediaPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('chat: $chat, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('mediaPath: $mediaPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, chat, role, kind, content, mediaPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.chat == this.chat &&
          other.role == this.role &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.mediaPath == this.mediaPath);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<int> chat;
  final Value<String> role;
  final Value<String> kind;
  final Value<String> content;
  final Value<String?> mediaPath;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.chat = const Value.absent(),
    this.role = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaPath = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required int chat,
    required String role,
    this.kind = const Value.absent(),
    required String content,
    this.mediaPath = const Value.absent(),
  }) : chat = Value(chat),
       role = Value(role),
       content = Value(content);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<int>? chat,
    Expression<String>? role,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? mediaPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (chat != null) 'chat': chat,
      if (role != null) 'role': role,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (mediaPath != null) 'media_path': mediaPath,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<int>? chat,
    Value<String>? role,
    Value<String>? kind,
    Value<String>? content,
    Value<String?>? mediaPath,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      chat: chat ?? this.chat,
      role: role ?? this.role,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      mediaPath: mediaPath ?? this.mediaPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (chat.present) {
      map['chat'] = Variable<int>(chat.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaPath.present) {
      map['media_path'] = Variable<String>(mediaPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('chat: $chat, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('mediaPath: $mediaPath')
          ..write(')'))
        .toString();
  }
}

class $ModelsTable extends Models with TableInfo<$ModelsTable, Model> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _apiUrlMeta = const VerificationMeta('apiUrl');
  @override
  late final GeneratedColumn<String> apiUrl = GeneratedColumn<String>(
    'api_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiTokenMeta = const VerificationMeta(
    'apiToken',
  );
  @override
  late final GeneratedColumn<String> apiToken = GeneratedColumn<String>(
    'api_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelTypeMeta = const VerificationMeta(
    'modelType',
  );
  @override
  late final GeneratedColumn<String> modelType = GeneratedColumn<String>(
    'model_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supportImageMeta = const VerificationMeta(
    'supportImage',
  );
  @override
  late final GeneratedColumn<bool> supportImage = GeneratedColumn<bool>(
    'support_image',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("support_image" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportAudioMeta = const VerificationMeta(
    'supportAudio',
  );
  @override
  late final GeneratedColumn<bool> supportAudio = GeneratedColumn<bool>(
    'support_audio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("support_audio" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsFunctionCallsMeta =
      const VerificationMeta('supportsFunctionCalls');
  @override
  late final GeneratedColumn<bool> supportsFunctionCalls =
      GeneratedColumn<bool>(
        'supports_function_calls',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("supports_function_calls" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _isThinkingMeta = const VerificationMeta(
    'isThinking',
  );
  @override
  late final GeneratedColumn<bool> isThinking = GeneratedColumn<bool>(
    'is_thinking',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_thinking" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.8),
  );
  static const VerificationMeta _topKMeta = const VerificationMeta('topK');
  @override
  late final GeneratedColumn<int> topK = GeneratedColumn<int>(
    'top_k',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _topPMeta = const VerificationMeta('topP');
  @override
  late final GeneratedColumn<double> topP = GeneratedColumn<double>(
    'top_p',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.95),
  );
  static const VerificationMeta _maxTokensMeta = const VerificationMeta(
    'maxTokens',
  );
  @override
  late final GeneratedColumn<int> maxTokens = GeneratedColumn<int>(
    'max_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2048),
  );
  static const VerificationMeta _tokenBufferMeta = const VerificationMeta(
    'tokenBuffer',
  );
  @override
  late final GeneratedColumn<int> tokenBuffer = GeneratedColumn<int>(
    'token_buffer',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(256),
  );
  static const VerificationMeta _randomSeedMeta = const VerificationMeta(
    'randomSeed',
  );
  @override
  late final GeneratedColumn<int> randomSeed = GeneratedColumn<int>(
    'random_seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _preferredBackendMeta = const VerificationMeta(
    'preferredBackend',
  );
  @override
  late final GeneratedColumn<String> preferredBackend = GeneratedColumn<String>(
    'preferred_backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('gpu'),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    name,
    description,
    modelId,
    provider,
    apiUrl,
    apiToken,
    modelType,
    supportImage,
    supportAudio,
    supportsFunctionCalls,
    isThinking,
    temperature,
    topK,
    topP,
    maxTokens,
    tokenBuffer,
    randomSeed,
    preferredBackend,
    sourceType,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models';
  @override
  VerificationContext validateIntegrity(
    Insertable<Model> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('api_url')) {
      context.handle(
        _apiUrlMeta,
        apiUrl.isAcceptableOrUnknown(data['api_url']!, _apiUrlMeta),
      );
    }
    if (data.containsKey('api_token')) {
      context.handle(
        _apiTokenMeta,
        apiToken.isAcceptableOrUnknown(data['api_token']!, _apiTokenMeta),
      );
    }
    if (data.containsKey('model_type')) {
      context.handle(
        _modelTypeMeta,
        modelType.isAcceptableOrUnknown(data['model_type']!, _modelTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_modelTypeMeta);
    }
    if (data.containsKey('support_image')) {
      context.handle(
        _supportImageMeta,
        supportImage.isAcceptableOrUnknown(
          data['support_image']!,
          _supportImageMeta,
        ),
      );
    }
    if (data.containsKey('support_audio')) {
      context.handle(
        _supportAudioMeta,
        supportAudio.isAcceptableOrUnknown(
          data['support_audio']!,
          _supportAudioMeta,
        ),
      );
    }
    if (data.containsKey('supports_function_calls')) {
      context.handle(
        _supportsFunctionCallsMeta,
        supportsFunctionCalls.isAcceptableOrUnknown(
          data['supports_function_calls']!,
          _supportsFunctionCallsMeta,
        ),
      );
    }
    if (data.containsKey('is_thinking')) {
      context.handle(
        _isThinkingMeta,
        isThinking.isAcceptableOrUnknown(data['is_thinking']!, _isThinkingMeta),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('top_k')) {
      context.handle(
        _topKMeta,
        topK.isAcceptableOrUnknown(data['top_k']!, _topKMeta),
      );
    }
    if (data.containsKey('top_p')) {
      context.handle(
        _topPMeta,
        topP.isAcceptableOrUnknown(data['top_p']!, _topPMeta),
      );
    }
    if (data.containsKey('max_tokens')) {
      context.handle(
        _maxTokensMeta,
        maxTokens.isAcceptableOrUnknown(data['max_tokens']!, _maxTokensMeta),
      );
    }
    if (data.containsKey('token_buffer')) {
      context.handle(
        _tokenBufferMeta,
        tokenBuffer.isAcceptableOrUnknown(
          data['token_buffer']!,
          _tokenBufferMeta,
        ),
      );
    }
    if (data.containsKey('random_seed')) {
      context.handle(
        _randomSeedMeta,
        randomSeed.isAcceptableOrUnknown(data['random_seed']!, _randomSeedMeta),
      );
    }
    if (data.containsKey('preferred_backend')) {
      context.handle(
        _preferredBackendMeta,
        preferredBackend.isAcceptableOrUnknown(
          data['preferred_backend']!,
          _preferredBackendMeta,
        ),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Model map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Model(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      apiUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_url'],
      ),
      apiToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_token'],
      ),
      modelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_type'],
      )!,
      supportImage: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}support_image'],
      )!,
      supportAudio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}support_audio'],
      )!,
      supportsFunctionCalls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_function_calls'],
      )!,
      isThinking: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_thinking'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      )!,
      topK: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}top_k'],
      )!,
      topP: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top_p'],
      )!,
      maxTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_tokens'],
      )!,
      tokenBuffer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_buffer'],
      )!,
      randomSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}random_seed'],
      )!,
      preferredBackend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_backend'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $ModelsTable createAlias(String alias) {
    return $ModelsTable(attachedDatabase, alias);
  }
}

class Model extends DataClass implements Insertable<Model> {
  final int id;
  final DateTime createdAt;
  final String name;
  final String description;
  final String? modelId;
  final String provider;
  final String? apiUrl;
  final String? apiToken;
  final String modelType;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final int tokenBuffer;
  final int randomSeed;
  final String preferredBackend;
  final String sourceType;
  final String source;
  const Model({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.description,
    this.modelId,
    required this.provider,
    this.apiUrl,
    this.apiToken,
    required this.modelType,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.isThinking,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.maxTokens,
    required this.tokenBuffer,
    required this.randomSeed,
    required this.preferredBackend,
    required this.sourceType,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || apiUrl != null) {
      map['api_url'] = Variable<String>(apiUrl);
    }
    if (!nullToAbsent || apiToken != null) {
      map['api_token'] = Variable<String>(apiToken);
    }
    map['model_type'] = Variable<String>(modelType);
    map['support_image'] = Variable<bool>(supportImage);
    map['support_audio'] = Variable<bool>(supportAudio);
    map['supports_function_calls'] = Variable<bool>(supportsFunctionCalls);
    map['is_thinking'] = Variable<bool>(isThinking);
    map['temperature'] = Variable<double>(temperature);
    map['top_k'] = Variable<int>(topK);
    map['top_p'] = Variable<double>(topP);
    map['max_tokens'] = Variable<int>(maxTokens);
    map['token_buffer'] = Variable<int>(tokenBuffer);
    map['random_seed'] = Variable<int>(randomSeed);
    map['preferred_backend'] = Variable<String>(preferredBackend);
    map['source_type'] = Variable<String>(sourceType);
    map['source'] = Variable<String>(source);
    return map;
  }

  ModelsCompanion toCompanion(bool nullToAbsent) {
    return ModelsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      name: Value(name),
      description: Value(description),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      provider: Value(provider),
      apiUrl: apiUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(apiUrl),
      apiToken: apiToken == null && nullToAbsent
          ? const Value.absent()
          : Value(apiToken),
      modelType: Value(modelType),
      supportImage: Value(supportImage),
      supportAudio: Value(supportAudio),
      supportsFunctionCalls: Value(supportsFunctionCalls),
      isThinking: Value(isThinking),
      temperature: Value(temperature),
      topK: Value(topK),
      topP: Value(topP),
      maxTokens: Value(maxTokens),
      tokenBuffer: Value(tokenBuffer),
      randomSeed: Value(randomSeed),
      preferredBackend: Value(preferredBackend),
      sourceType: Value(sourceType),
      source: Value(source),
    );
  }

  factory Model.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Model(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      provider: serializer.fromJson<String>(json['provider']),
      apiUrl: serializer.fromJson<String?>(json['apiUrl']),
      apiToken: serializer.fromJson<String?>(json['apiToken']),
      modelType: serializer.fromJson<String>(json['modelType']),
      supportImage: serializer.fromJson<bool>(json['supportImage']),
      supportAudio: serializer.fromJson<bool>(json['supportAudio']),
      supportsFunctionCalls: serializer.fromJson<bool>(
        json['supportsFunctionCalls'],
      ),
      isThinking: serializer.fromJson<bool>(json['isThinking']),
      temperature: serializer.fromJson<double>(json['temperature']),
      topK: serializer.fromJson<int>(json['topK']),
      topP: serializer.fromJson<double>(json['topP']),
      maxTokens: serializer.fromJson<int>(json['maxTokens']),
      tokenBuffer: serializer.fromJson<int>(json['tokenBuffer']),
      randomSeed: serializer.fromJson<int>(json['randomSeed']),
      preferredBackend: serializer.fromJson<String>(json['preferredBackend']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'modelId': serializer.toJson<String?>(modelId),
      'provider': serializer.toJson<String>(provider),
      'apiUrl': serializer.toJson<String?>(apiUrl),
      'apiToken': serializer.toJson<String?>(apiToken),
      'modelType': serializer.toJson<String>(modelType),
      'supportImage': serializer.toJson<bool>(supportImage),
      'supportAudio': serializer.toJson<bool>(supportAudio),
      'supportsFunctionCalls': serializer.toJson<bool>(supportsFunctionCalls),
      'isThinking': serializer.toJson<bool>(isThinking),
      'temperature': serializer.toJson<double>(temperature),
      'topK': serializer.toJson<int>(topK),
      'topP': serializer.toJson<double>(topP),
      'maxTokens': serializer.toJson<int>(maxTokens),
      'tokenBuffer': serializer.toJson<int>(tokenBuffer),
      'randomSeed': serializer.toJson<int>(randomSeed),
      'preferredBackend': serializer.toJson<String>(preferredBackend),
      'sourceType': serializer.toJson<String>(sourceType),
      'source': serializer.toJson<String>(source),
    };
  }

  Model copyWith({
    int? id,
    DateTime? createdAt,
    String? name,
    String? description,
    Value<String?> modelId = const Value.absent(),
    String? provider,
    Value<String?> apiUrl = const Value.absent(),
    Value<String?> apiToken = const Value.absent(),
    String? modelType,
    bool? supportImage,
    bool? supportAudio,
    bool? supportsFunctionCalls,
    bool? isThinking,
    double? temperature,
    int? topK,
    double? topP,
    int? maxTokens,
    int? tokenBuffer,
    int? randomSeed,
    String? preferredBackend,
    String? sourceType,
    String? source,
  }) => Model(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    name: name ?? this.name,
    description: description ?? this.description,
    modelId: modelId.present ? modelId.value : this.modelId,
    provider: provider ?? this.provider,
    apiUrl: apiUrl.present ? apiUrl.value : this.apiUrl,
    apiToken: apiToken.present ? apiToken.value : this.apiToken,
    modelType: modelType ?? this.modelType,
    supportImage: supportImage ?? this.supportImage,
    supportAudio: supportAudio ?? this.supportAudio,
    supportsFunctionCalls: supportsFunctionCalls ?? this.supportsFunctionCalls,
    isThinking: isThinking ?? this.isThinking,
    temperature: temperature ?? this.temperature,
    topK: topK ?? this.topK,
    topP: topP ?? this.topP,
    maxTokens: maxTokens ?? this.maxTokens,
    tokenBuffer: tokenBuffer ?? this.tokenBuffer,
    randomSeed: randomSeed ?? this.randomSeed,
    preferredBackend: preferredBackend ?? this.preferredBackend,
    sourceType: sourceType ?? this.sourceType,
    source: source ?? this.source,
  );
  Model copyWithCompanion(ModelsCompanion data) {
    return Model(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      provider: data.provider.present ? data.provider.value : this.provider,
      apiUrl: data.apiUrl.present ? data.apiUrl.value : this.apiUrl,
      apiToken: data.apiToken.present ? data.apiToken.value : this.apiToken,
      modelType: data.modelType.present ? data.modelType.value : this.modelType,
      supportImage: data.supportImage.present
          ? data.supportImage.value
          : this.supportImage,
      supportAudio: data.supportAudio.present
          ? data.supportAudio.value
          : this.supportAudio,
      supportsFunctionCalls: data.supportsFunctionCalls.present
          ? data.supportsFunctionCalls.value
          : this.supportsFunctionCalls,
      isThinking: data.isThinking.present
          ? data.isThinking.value
          : this.isThinking,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      topK: data.topK.present ? data.topK.value : this.topK,
      topP: data.topP.present ? data.topP.value : this.topP,
      maxTokens: data.maxTokens.present ? data.maxTokens.value : this.maxTokens,
      tokenBuffer: data.tokenBuffer.present
          ? data.tokenBuffer.value
          : this.tokenBuffer,
      randomSeed: data.randomSeed.present
          ? data.randomSeed.value
          : this.randomSeed,
      preferredBackend: data.preferredBackend.present
          ? data.preferredBackend.value
          : this.preferredBackend,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Model(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('apiUrl: $apiUrl, ')
          ..write('apiToken: $apiToken, ')
          ..write('modelType: $modelType, ')
          ..write('supportImage: $supportImage, ')
          ..write('supportAudio: $supportAudio, ')
          ..write('supportsFunctionCalls: $supportsFunctionCalls, ')
          ..write('isThinking: $isThinking, ')
          ..write('temperature: $temperature, ')
          ..write('topK: $topK, ')
          ..write('topP: $topP, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('tokenBuffer: $tokenBuffer, ')
          ..write('randomSeed: $randomSeed, ')
          ..write('preferredBackend: $preferredBackend, ')
          ..write('sourceType: $sourceType, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    name,
    description,
    modelId,
    provider,
    apiUrl,
    apiToken,
    modelType,
    supportImage,
    supportAudio,
    supportsFunctionCalls,
    isThinking,
    temperature,
    topK,
    topP,
    maxTokens,
    tokenBuffer,
    randomSeed,
    preferredBackend,
    sourceType,
    source,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.name == this.name &&
          other.description == this.description &&
          other.modelId == this.modelId &&
          other.provider == this.provider &&
          other.apiUrl == this.apiUrl &&
          other.apiToken == this.apiToken &&
          other.modelType == this.modelType &&
          other.supportImage == this.supportImage &&
          other.supportAudio == this.supportAudio &&
          other.supportsFunctionCalls == this.supportsFunctionCalls &&
          other.isThinking == this.isThinking &&
          other.temperature == this.temperature &&
          other.topK == this.topK &&
          other.topP == this.topP &&
          other.maxTokens == this.maxTokens &&
          other.tokenBuffer == this.tokenBuffer &&
          other.randomSeed == this.randomSeed &&
          other.preferredBackend == this.preferredBackend &&
          other.sourceType == this.sourceType &&
          other.source == this.source);
}

class ModelsCompanion extends UpdateCompanion<Model> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> name;
  final Value<String> description;
  final Value<String?> modelId;
  final Value<String> provider;
  final Value<String?> apiUrl;
  final Value<String?> apiToken;
  final Value<String> modelType;
  final Value<bool> supportImage;
  final Value<bool> supportAudio;
  final Value<bool> supportsFunctionCalls;
  final Value<bool> isThinking;
  final Value<double> temperature;
  final Value<int> topK;
  final Value<double> topP;
  final Value<int> maxTokens;
  final Value<int> tokenBuffer;
  final Value<int> randomSeed;
  final Value<String> preferredBackend;
  final Value<String> sourceType;
  final Value<String> source;
  const ModelsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.modelId = const Value.absent(),
    this.provider = const Value.absent(),
    this.apiUrl = const Value.absent(),
    this.apiToken = const Value.absent(),
    this.modelType = const Value.absent(),
    this.supportImage = const Value.absent(),
    this.supportAudio = const Value.absent(),
    this.supportsFunctionCalls = const Value.absent(),
    this.isThinking = const Value.absent(),
    this.temperature = const Value.absent(),
    this.topK = const Value.absent(),
    this.topP = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.tokenBuffer = const Value.absent(),
    this.randomSeed = const Value.absent(),
    this.preferredBackend = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.source = const Value.absent(),
  });
  ModelsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String name,
    required String description,
    this.modelId = const Value.absent(),
    this.provider = const Value.absent(),
    this.apiUrl = const Value.absent(),
    this.apiToken = const Value.absent(),
    required String modelType,
    this.supportImage = const Value.absent(),
    this.supportAudio = const Value.absent(),
    this.supportsFunctionCalls = const Value.absent(),
    this.isThinking = const Value.absent(),
    this.temperature = const Value.absent(),
    this.topK = const Value.absent(),
    this.topP = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.tokenBuffer = const Value.absent(),
    this.randomSeed = const Value.absent(),
    this.preferredBackend = const Value.absent(),
    required String sourceType,
    required String source,
  }) : name = Value(name),
       description = Value(description),
       modelType = Value(modelType),
       sourceType = Value(sourceType),
       source = Value(source);
  static Insertable<Model> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? modelId,
    Expression<String>? provider,
    Expression<String>? apiUrl,
    Expression<String>? apiToken,
    Expression<String>? modelType,
    Expression<bool>? supportImage,
    Expression<bool>? supportAudio,
    Expression<bool>? supportsFunctionCalls,
    Expression<bool>? isThinking,
    Expression<double>? temperature,
    Expression<int>? topK,
    Expression<double>? topP,
    Expression<int>? maxTokens,
    Expression<int>? tokenBuffer,
    Expression<int>? randomSeed,
    Expression<String>? preferredBackend,
    Expression<String>? sourceType,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (modelId != null) 'model_id': modelId,
      if (provider != null) 'provider': provider,
      if (apiUrl != null) 'api_url': apiUrl,
      if (apiToken != null) 'api_token': apiToken,
      if (modelType != null) 'model_type': modelType,
      if (supportImage != null) 'support_image': supportImage,
      if (supportAudio != null) 'support_audio': supportAudio,
      if (supportsFunctionCalls != null)
        'supports_function_calls': supportsFunctionCalls,
      if (isThinking != null) 'is_thinking': isThinking,
      if (temperature != null) 'temperature': temperature,
      if (topK != null) 'top_k': topK,
      if (topP != null) 'top_p': topP,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (tokenBuffer != null) 'token_buffer': tokenBuffer,
      if (randomSeed != null) 'random_seed': randomSeed,
      if (preferredBackend != null) 'preferred_backend': preferredBackend,
      if (sourceType != null) 'source_type': sourceType,
      if (source != null) 'source': source,
    });
  }

  ModelsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? name,
    Value<String>? description,
    Value<String?>? modelId,
    Value<String>? provider,
    Value<String?>? apiUrl,
    Value<String?>? apiToken,
    Value<String>? modelType,
    Value<bool>? supportImage,
    Value<bool>? supportAudio,
    Value<bool>? supportsFunctionCalls,
    Value<bool>? isThinking,
    Value<double>? temperature,
    Value<int>? topK,
    Value<double>? topP,
    Value<int>? maxTokens,
    Value<int>? tokenBuffer,
    Value<int>? randomSeed,
    Value<String>? preferredBackend,
    Value<String>? sourceType,
    Value<String>? source,
  }) {
    return ModelsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      description: description ?? this.description,
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      apiUrl: apiUrl ?? this.apiUrl,
      apiToken: apiToken ?? this.apiToken,
      modelType: modelType ?? this.modelType,
      supportImage: supportImage ?? this.supportImage,
      supportAudio: supportAudio ?? this.supportAudio,
      supportsFunctionCalls:
          supportsFunctionCalls ?? this.supportsFunctionCalls,
      isThinking: isThinking ?? this.isThinking,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      tokenBuffer: tokenBuffer ?? this.tokenBuffer,
      randomSeed: randomSeed ?? this.randomSeed,
      preferredBackend: preferredBackend ?? this.preferredBackend,
      sourceType: sourceType ?? this.sourceType,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (apiUrl.present) {
      map['api_url'] = Variable<String>(apiUrl.value);
    }
    if (apiToken.present) {
      map['api_token'] = Variable<String>(apiToken.value);
    }
    if (modelType.present) {
      map['model_type'] = Variable<String>(modelType.value);
    }
    if (supportImage.present) {
      map['support_image'] = Variable<bool>(supportImage.value);
    }
    if (supportAudio.present) {
      map['support_audio'] = Variable<bool>(supportAudio.value);
    }
    if (supportsFunctionCalls.present) {
      map['supports_function_calls'] = Variable<bool>(
        supportsFunctionCalls.value,
      );
    }
    if (isThinking.present) {
      map['is_thinking'] = Variable<bool>(isThinking.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (topK.present) {
      map['top_k'] = Variable<int>(topK.value);
    }
    if (topP.present) {
      map['top_p'] = Variable<double>(topP.value);
    }
    if (maxTokens.present) {
      map['max_tokens'] = Variable<int>(maxTokens.value);
    }
    if (tokenBuffer.present) {
      map['token_buffer'] = Variable<int>(tokenBuffer.value);
    }
    if (randomSeed.present) {
      map['random_seed'] = Variable<int>(randomSeed.value);
    }
    if (preferredBackend.present) {
      map['preferred_backend'] = Variable<String>(preferredBackend.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('modelId: $modelId, ')
          ..write('provider: $provider, ')
          ..write('apiUrl: $apiUrl, ')
          ..write('apiToken: $apiToken, ')
          ..write('modelType: $modelType, ')
          ..write('supportImage: $supportImage, ')
          ..write('supportAudio: $supportAudio, ')
          ..write('supportsFunctionCalls: $supportsFunctionCalls, ')
          ..write('isThinking: $isThinking, ')
          ..write('temperature: $temperature, ')
          ..write('topK: $topK, ')
          ..write('topP: $topP, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('tokenBuffer: $tokenBuffer, ')
          ..write('randomSeed: $randomSeed, ')
          ..write('preferredBackend: $preferredBackend, ')
          ..write('sourceType: $sourceType, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

abstract class _$GenaDatabase extends GeneratedDatabase {
  _$GenaDatabase(QueryExecutor e) : super(e);
  $GenaDatabaseManager get managers => $GenaDatabaseManager(this);
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $WorkspaceDocumentsTable workspaceDocuments =
      $WorkspaceDocumentsTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ModelsTable models = $ModelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workspaces,
    workspaceDocuments,
    chats,
    messages,
    models,
  ];
}

typedef $$WorkspacesTableCreateCompanionBuilder =
    WorkspacesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required String name,
      Value<String> generalInstruction,
      Value<bool> ragEnabled,
      Value<bool> nativeToolsEnabled,
      Value<bool> nativeOpenUrlEnabled,
      Value<bool> nativeOpenAppEnabled,
      Value<bool> nativeSendEmailEnabled,
      Value<bool> nativeFlashlightEnabled,
    });
typedef $$WorkspacesTableUpdateCompanionBuilder =
    WorkspacesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> name,
      Value<String> generalInstruction,
      Value<bool> ragEnabled,
      Value<bool> nativeToolsEnabled,
      Value<bool> nativeOpenUrlEnabled,
      Value<bool> nativeOpenAppEnabled,
      Value<bool> nativeSendEmailEnabled,
      Value<bool> nativeFlashlightEnabled,
    });

final class $$WorkspacesTableReferences
    extends BaseReferences<_$GenaDatabase, $WorkspacesTable, Workspace> {
  $$WorkspacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkspaceDocumentsTable, List<WorkspaceDocument>>
  _workspaceDocumentsRefsTable(_$GenaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workspaceDocuments,
        aliasName: $_aliasNameGenerator(
          db.workspaces.id,
          db.workspaceDocuments.workspace,
        ),
      );

  $$WorkspaceDocumentsTableProcessedTableManager get workspaceDocumentsRefs {
    final manager = $$WorkspaceDocumentsTableTableManager(
      $_db,
      $_db.workspaceDocuments,
    ).filter((f) => f.workspace.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workspaceDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChatsTable, List<Chat>> _chatsRefsTable(
    _$GenaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chats,
    aliasName: $_aliasNameGenerator(db.workspaces.id, db.chats.workspace),
  );

  $$ChatsTableProcessedTableManager get chatsRefs {
    final manager = $$ChatsTableTableManager(
      $_db,
      $_db.chats,
    ).filter((f) => f.workspace.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkspacesTableFilterComposer
    extends Composer<_$GenaDatabase, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generalInstruction => $composableBuilder(
    column: $table.generalInstruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ragEnabled => $composableBuilder(
    column: $table.ragEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nativeToolsEnabled => $composableBuilder(
    column: $table.nativeToolsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nativeOpenUrlEnabled => $composableBuilder(
    column: $table.nativeOpenUrlEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nativeOpenAppEnabled => $composableBuilder(
    column: $table.nativeOpenAppEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nativeSendEmailEnabled => $composableBuilder(
    column: $table.nativeSendEmailEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nativeFlashlightEnabled => $composableBuilder(
    column: $table.nativeFlashlightEnabled,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workspaceDocumentsRefs(
    Expression<bool> Function($$WorkspaceDocumentsTableFilterComposer f) f,
  ) {
    final $$WorkspaceDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workspaceDocuments,
      getReferencedColumn: (t) => t.workspace,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspaceDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.workspaceDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chatsRefs(
    Expression<bool> Function($$ChatsTableFilterComposer f) f,
  ) {
    final $$ChatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chats,
      getReferencedColumn: (t) => t.workspace,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatsTableFilterComposer(
            $db: $db,
            $table: $db.chats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$GenaDatabase, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generalInstruction => $composableBuilder(
    column: $table.generalInstruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ragEnabled => $composableBuilder(
    column: $table.ragEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nativeToolsEnabled => $composableBuilder(
    column: $table.nativeToolsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nativeOpenUrlEnabled => $composableBuilder(
    column: $table.nativeOpenUrlEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nativeOpenAppEnabled => $composableBuilder(
    column: $table.nativeOpenAppEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nativeSendEmailEnabled => $composableBuilder(
    column: $table.nativeSendEmailEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nativeFlashlightEnabled => $composableBuilder(
    column: $table.nativeFlashlightEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$GenaDatabase, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get generalInstruction => $composableBuilder(
    column: $table.generalInstruction,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ragEnabled => $composableBuilder(
    column: $table.ragEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nativeToolsEnabled => $composableBuilder(
    column: $table.nativeToolsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nativeOpenUrlEnabled => $composableBuilder(
    column: $table.nativeOpenUrlEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nativeOpenAppEnabled => $composableBuilder(
    column: $table.nativeOpenAppEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nativeSendEmailEnabled => $composableBuilder(
    column: $table.nativeSendEmailEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nativeFlashlightEnabled => $composableBuilder(
    column: $table.nativeFlashlightEnabled,
    builder: (column) => column,
  );

  Expression<T> workspaceDocumentsRefs<T extends Object>(
    Expression<T> Function($$WorkspaceDocumentsTableAnnotationComposer a) f,
  ) {
    final $$WorkspaceDocumentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workspaceDocuments,
          getReferencedColumn: (t) => t.workspace,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkspaceDocumentsTableAnnotationComposer(
                $db: $db,
                $table: $db.workspaceDocuments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> chatsRefs<T extends Object>(
    Expression<T> Function($$ChatsTableAnnotationComposer a) f,
  ) {
    final $$ChatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chats,
      getReferencedColumn: (t) => t.workspace,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatsTableAnnotationComposer(
            $db: $db,
            $table: $db.chats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkspacesTableTableManager
    extends
        RootTableManager<
          _$GenaDatabase,
          $WorkspacesTable,
          Workspace,
          $$WorkspacesTableFilterComposer,
          $$WorkspacesTableOrderingComposer,
          $$WorkspacesTableAnnotationComposer,
          $$WorkspacesTableCreateCompanionBuilder,
          $$WorkspacesTableUpdateCompanionBuilder,
          (Workspace, $$WorkspacesTableReferences),
          Workspace,
          PrefetchHooks Function({bool workspaceDocumentsRefs, bool chatsRefs})
        > {
  $$WorkspacesTableTableManager(_$GenaDatabase db, $WorkspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> generalInstruction = const Value.absent(),
                Value<bool> ragEnabled = const Value.absent(),
                Value<bool> nativeToolsEnabled = const Value.absent(),
                Value<bool> nativeOpenUrlEnabled = const Value.absent(),
                Value<bool> nativeOpenAppEnabled = const Value.absent(),
                Value<bool> nativeSendEmailEnabled = const Value.absent(),
                Value<bool> nativeFlashlightEnabled = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                createdAt: createdAt,
                name: name,
                generalInstruction: generalInstruction,
                ragEnabled: ragEnabled,
                nativeToolsEnabled: nativeToolsEnabled,
                nativeOpenUrlEnabled: nativeOpenUrlEnabled,
                nativeOpenAppEnabled: nativeOpenAppEnabled,
                nativeSendEmailEnabled: nativeSendEmailEnabled,
                nativeFlashlightEnabled: nativeFlashlightEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required String name,
                Value<String> generalInstruction = const Value.absent(),
                Value<bool> ragEnabled = const Value.absent(),
                Value<bool> nativeToolsEnabled = const Value.absent(),
                Value<bool> nativeOpenUrlEnabled = const Value.absent(),
                Value<bool> nativeOpenAppEnabled = const Value.absent(),
                Value<bool> nativeSendEmailEnabled = const Value.absent(),
                Value<bool> nativeFlashlightEnabled = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                createdAt: createdAt,
                name: name,
                generalInstruction: generalInstruction,
                ragEnabled: ragEnabled,
                nativeToolsEnabled: nativeToolsEnabled,
                nativeOpenUrlEnabled: nativeOpenUrlEnabled,
                nativeOpenAppEnabled: nativeOpenAppEnabled,
                nativeSendEmailEnabled: nativeSendEmailEnabled,
                nativeFlashlightEnabled: nativeFlashlightEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkspacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({workspaceDocumentsRefs = false, chatsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workspaceDocumentsRefs) db.workspaceDocuments,
                    if (chatsRefs) db.chats,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workspaceDocumentsRefs)
                        await $_getPrefetchedData<
                          Workspace,
                          $WorkspacesTable,
                          WorkspaceDocument
                        >(
                          currentTable: table,
                          referencedTable: $$WorkspacesTableReferences
                              ._workspaceDocumentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkspacesTableReferences(
                                db,
                                table,
                                p0,
                              ).workspaceDocumentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workspace == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (chatsRefs)
                        await $_getPrefetchedData<
                          Workspace,
                          $WorkspacesTable,
                          Chat
                        >(
                          currentTable: table,
                          referencedTable: $$WorkspacesTableReferences
                              ._chatsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkspacesTableReferences(
                                db,
                                table,
                                p0,
                              ).chatsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workspace == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$GenaDatabase,
      $WorkspacesTable,
      Workspace,
      $$WorkspacesTableFilterComposer,
      $$WorkspacesTableOrderingComposer,
      $$WorkspacesTableAnnotationComposer,
      $$WorkspacesTableCreateCompanionBuilder,
      $$WorkspacesTableUpdateCompanionBuilder,
      (Workspace, $$WorkspacesTableReferences),
      Workspace,
      PrefetchHooks Function({bool workspaceDocumentsRefs, bool chatsRefs})
    >;
typedef $$WorkspaceDocumentsTableCreateCompanionBuilder =
    WorkspaceDocumentsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required int workspace,
      required String name,
      required String sourceType,
      required String sourcePath,
      required String content,
      Value<String> ingestionStatus,
      Value<String?> ingestionError,
      Value<int> chunkCount,
    });
typedef $$WorkspaceDocumentsTableUpdateCompanionBuilder =
    WorkspaceDocumentsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<int> workspace,
      Value<String> name,
      Value<String> sourceType,
      Value<String> sourcePath,
      Value<String> content,
      Value<String> ingestionStatus,
      Value<String?> ingestionError,
      Value<int> chunkCount,
    });

final class $$WorkspaceDocumentsTableReferences
    extends
        BaseReferences<
          _$GenaDatabase,
          $WorkspaceDocumentsTable,
          WorkspaceDocument
        > {
  $$WorkspaceDocumentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkspacesTable _workspaceTable(_$GenaDatabase db) =>
      db.workspaces.createAlias(
        $_aliasNameGenerator(db.workspaceDocuments.workspace, db.workspaces.id),
      );

  $$WorkspacesTableProcessedTableManager get workspace {
    final $_column = $_itemColumn<int>('workspace')!;

    final manager = $$WorkspacesTableTableManager(
      $_db,
      $_db.workspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workspaceTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkspaceDocumentsTableFilterComposer
    extends Composer<_$GenaDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestionStatus => $composableBuilder(
    column: $table.ingestionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestionError => $composableBuilder(
    column: $table.ingestionError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkspacesTableFilterComposer get workspace {
    final $$WorkspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableFilterComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceDocumentsTableOrderingComposer
    extends Composer<_$GenaDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestionStatus => $composableBuilder(
    column: $table.ingestionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestionError => $composableBuilder(
    column: $table.ingestionError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkspacesTableOrderingComposer get workspace {
    final $$WorkspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableOrderingComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceDocumentsTableAnnotationComposer
    extends Composer<_$GenaDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get ingestionStatus => $composableBuilder(
    column: $table.ingestionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ingestionError => $composableBuilder(
    column: $table.ingestionError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chunkCount => $composableBuilder(
    column: $table.chunkCount,
    builder: (column) => column,
  );

  $$WorkspacesTableAnnotationComposer get workspace {
    final $$WorkspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceDocumentsTableTableManager
    extends
        RootTableManager<
          _$GenaDatabase,
          $WorkspaceDocumentsTable,
          WorkspaceDocument,
          $$WorkspaceDocumentsTableFilterComposer,
          $$WorkspaceDocumentsTableOrderingComposer,
          $$WorkspaceDocumentsTableAnnotationComposer,
          $$WorkspaceDocumentsTableCreateCompanionBuilder,
          $$WorkspaceDocumentsTableUpdateCompanionBuilder,
          (WorkspaceDocument, $$WorkspaceDocumentsTableReferences),
          WorkspaceDocument,
          PrefetchHooks Function({bool workspace})
        > {
  $$WorkspaceDocumentsTableTableManager(
    _$GenaDatabase db,
    $WorkspaceDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspaceDocumentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> workspace = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> ingestionStatus = const Value.absent(),
                Value<String?> ingestionError = const Value.absent(),
                Value<int> chunkCount = const Value.absent(),
              }) => WorkspaceDocumentsCompanion(
                id: id,
                createdAt: createdAt,
                workspace: workspace,
                name: name,
                sourceType: sourceType,
                sourcePath: sourcePath,
                content: content,
                ingestionStatus: ingestionStatus,
                ingestionError: ingestionError,
                chunkCount: chunkCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required int workspace,
                required String name,
                required String sourceType,
                required String sourcePath,
                required String content,
                Value<String> ingestionStatus = const Value.absent(),
                Value<String?> ingestionError = const Value.absent(),
                Value<int> chunkCount = const Value.absent(),
              }) => WorkspaceDocumentsCompanion.insert(
                id: id,
                createdAt: createdAt,
                workspace: workspace,
                name: name,
                sourceType: sourceType,
                sourcePath: sourcePath,
                content: content,
                ingestionStatus: ingestionStatus,
                ingestionError: ingestionError,
                chunkCount: chunkCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkspaceDocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workspace = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workspace) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workspace,
                                referencedTable:
                                    $$WorkspaceDocumentsTableReferences
                                        ._workspaceTable(db),
                                referencedColumn:
                                    $$WorkspaceDocumentsTableReferences
                                        ._workspaceTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkspaceDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$GenaDatabase,
      $WorkspaceDocumentsTable,
      WorkspaceDocument,
      $$WorkspaceDocumentsTableFilterComposer,
      $$WorkspaceDocumentsTableOrderingComposer,
      $$WorkspaceDocumentsTableAnnotationComposer,
      $$WorkspaceDocumentsTableCreateCompanionBuilder,
      $$WorkspaceDocumentsTableUpdateCompanionBuilder,
      (WorkspaceDocument, $$WorkspaceDocumentsTableReferences),
      WorkspaceDocument,
      PrefetchHooks Function({bool workspace})
    >;
typedef $$ChatsTableCreateCompanionBuilder =
    ChatsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required int workspace,
      required String title,
    });
typedef $$ChatsTableUpdateCompanionBuilder =
    ChatsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<int> workspace,
      Value<String> title,
    });

final class $$ChatsTableReferences
    extends BaseReferences<_$GenaDatabase, $ChatsTable, Chat> {
  $$ChatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkspacesTable _workspaceTable(_$GenaDatabase db) => db.workspaces
      .createAlias($_aliasNameGenerator(db.chats.workspace, db.workspaces.id));

  $$WorkspacesTableProcessedTableManager get workspace {
    final $_column = $_itemColumn<int>('workspace')!;

    final manager = $$WorkspacesTableTableManager(
      $_db,
      $_db.workspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workspaceTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$GenaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.chats.id, db.messages.chat),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.chat.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChatsTableFilterComposer extends Composer<_$GenaDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkspacesTableFilterComposer get workspace {
    final $$WorkspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableFilterComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.chat,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChatsTableOrderingComposer
    extends Composer<_$GenaDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkspacesTableOrderingComposer get workspace {
    final $$WorkspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableOrderingComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$GenaDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$WorkspacesTableAnnotationComposer get workspace {
    final $$WorkspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workspace,
      referencedTable: $db.workspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.workspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.chat,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChatsTableTableManager
    extends
        RootTableManager<
          _$GenaDatabase,
          $ChatsTable,
          Chat,
          $$ChatsTableFilterComposer,
          $$ChatsTableOrderingComposer,
          $$ChatsTableAnnotationComposer,
          $$ChatsTableCreateCompanionBuilder,
          $$ChatsTableUpdateCompanionBuilder,
          (Chat, $$ChatsTableReferences),
          Chat,
          PrefetchHooks Function({bool workspace, bool messagesRefs})
        > {
  $$ChatsTableTableManager(_$GenaDatabase db, $ChatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> workspace = const Value.absent(),
                Value<String> title = const Value.absent(),
              }) => ChatsCompanion(
                id: id,
                createdAt: createdAt,
                workspace: workspace,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required int workspace,
                required String title,
              }) => ChatsCompanion.insert(
                id: id,
                createdAt: createdAt,
                workspace: workspace,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ChatsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({workspace = false, messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workspace) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workspace,
                                referencedTable: $$ChatsTableReferences
                                    ._workspaceTable(db),
                                referencedColumn: $$ChatsTableReferences
                                    ._workspaceTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<Chat, $ChatsTable, Message>(
                      currentTable: table,
                      referencedTable: $$ChatsTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ChatsTableReferences(db, table, p0).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.chat == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ChatsTableProcessedTableManager =
    ProcessedTableManager<
      _$GenaDatabase,
      $ChatsTable,
      Chat,
      $$ChatsTableFilterComposer,
      $$ChatsTableOrderingComposer,
      $$ChatsTableAnnotationComposer,
      $$ChatsTableCreateCompanionBuilder,
      $$ChatsTableUpdateCompanionBuilder,
      (Chat, $$ChatsTableReferences),
      Chat,
      PrefetchHooks Function({bool workspace, bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required int chat,
      required String role,
      Value<String> kind,
      required String content,
      Value<String?> mediaPath,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<int> chat,
      Value<String> role,
      Value<String> kind,
      Value<String> content,
      Value<String?> mediaPath,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$GenaDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChatsTable _chatTable(_$GenaDatabase db) =>
      db.chats.createAlias($_aliasNameGenerator(db.messages.chat, db.chats.id));

  $$ChatsTableProcessedTableManager get chat {
    final $_column = $_itemColumn<int>('chat')!;

    final manager = $$ChatsTableTableManager(
      $_db,
      $_db.chats,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chatTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$GenaDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaPath => $composableBuilder(
    column: $table.mediaPath,
    builder: (column) => ColumnFilters(column),
  );

  $$ChatsTableFilterComposer get chat {
    final $$ChatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chat,
      referencedTable: $db.chats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatsTableFilterComposer(
            $db: $db,
            $table: $db.chats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$GenaDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaPath => $composableBuilder(
    column: $table.mediaPath,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChatsTableOrderingComposer get chat {
    final $$ChatsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chat,
      referencedTable: $db.chats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatsTableOrderingComposer(
            $db: $db,
            $table: $db.chats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$GenaDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mediaPath =>
      $composableBuilder(column: $table.mediaPath, builder: (column) => column);

  $$ChatsTableAnnotationComposer get chat {
    final $$ChatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chat,
      referencedTable: $db.chats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatsTableAnnotationComposer(
            $db: $db,
            $table: $db.chats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$GenaDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool chat})
        > {
  $$MessagesTableTableManager(_$GenaDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> chat = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> mediaPath = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                createdAt: createdAt,
                chat: chat,
                role: role,
                kind: kind,
                content: content,
                mediaPath: mediaPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required int chat,
                required String role,
                Value<String> kind = const Value.absent(),
                required String content,
                Value<String?> mediaPath = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                createdAt: createdAt,
                chat: chat,
                role: role,
                kind: kind,
                content: content,
                mediaPath: mediaPath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chat = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (chat) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.chat,
                                referencedTable: $$MessagesTableReferences
                                    ._chatTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._chatTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$GenaDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool chat})
    >;
typedef $$ModelsTableCreateCompanionBuilder =
    ModelsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required String name,
      required String description,
      Value<String?> modelId,
      Value<String> provider,
      Value<String?> apiUrl,
      Value<String?> apiToken,
      required String modelType,
      Value<bool> supportImage,
      Value<bool> supportAudio,
      Value<bool> supportsFunctionCalls,
      Value<bool> isThinking,
      Value<double> temperature,
      Value<int> topK,
      Value<double> topP,
      Value<int> maxTokens,
      Value<int> tokenBuffer,
      Value<int> randomSeed,
      Value<String> preferredBackend,
      required String sourceType,
      required String source,
    });
typedef $$ModelsTableUpdateCompanionBuilder =
    ModelsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> name,
      Value<String> description,
      Value<String?> modelId,
      Value<String> provider,
      Value<String?> apiUrl,
      Value<String?> apiToken,
      Value<String> modelType,
      Value<bool> supportImage,
      Value<bool> supportAudio,
      Value<bool> supportsFunctionCalls,
      Value<bool> isThinking,
      Value<double> temperature,
      Value<int> topK,
      Value<double> topP,
      Value<int> maxTokens,
      Value<int> tokenBuffer,
      Value<int> randomSeed,
      Value<String> preferredBackend,
      Value<String> sourceType,
      Value<String> source,
    });

class $$ModelsTableFilterComposer
    extends Composer<_$GenaDatabase, $ModelsTable> {
  $$ModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiUrl => $composableBuilder(
    column: $table.apiUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportImage => $composableBuilder(
    column: $table.supportImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportAudio => $composableBuilder(
    column: $table.supportAudio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsFunctionCalls => $composableBuilder(
    column: $table.supportsFunctionCalls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isThinking => $composableBuilder(
    column: $table.isThinking,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topK => $composableBuilder(
    column: $table.topK,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenBuffer => $composableBuilder(
    column: $table.tokenBuffer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get randomSeed => $composableBuilder(
    column: $table.randomSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredBackend => $composableBuilder(
    column: $table.preferredBackend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelsTableOrderingComposer
    extends Composer<_$GenaDatabase, $ModelsTable> {
  $$ModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiUrl => $composableBuilder(
    column: $table.apiUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportImage => $composableBuilder(
    column: $table.supportImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportAudio => $composableBuilder(
    column: $table.supportAudio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsFunctionCalls => $composableBuilder(
    column: $table.supportsFunctionCalls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isThinking => $composableBuilder(
    column: $table.isThinking,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topK => $composableBuilder(
    column: $table.topK,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxTokens => $composableBuilder(
    column: $table.maxTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenBuffer => $composableBuilder(
    column: $table.tokenBuffer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get randomSeed => $composableBuilder(
    column: $table.randomSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredBackend => $composableBuilder(
    column: $table.preferredBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelsTableAnnotationComposer
    extends Composer<_$GenaDatabase, $ModelsTable> {
  $$ModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get apiUrl =>
      $composableBuilder(column: $table.apiUrl, builder: (column) => column);

  GeneratedColumn<String> get apiToken =>
      $composableBuilder(column: $table.apiToken, builder: (column) => column);

  GeneratedColumn<String> get modelType =>
      $composableBuilder(column: $table.modelType, builder: (column) => column);

  GeneratedColumn<bool> get supportImage => $composableBuilder(
    column: $table.supportImage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportAudio => $composableBuilder(
    column: $table.supportAudio,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsFunctionCalls => $composableBuilder(
    column: $table.supportsFunctionCalls,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isThinking => $composableBuilder(
    column: $table.isThinking,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get topK =>
      $composableBuilder(column: $table.topK, builder: (column) => column);

  GeneratedColumn<double> get topP =>
      $composableBuilder(column: $table.topP, builder: (column) => column);

  GeneratedColumn<int> get maxTokens =>
      $composableBuilder(column: $table.maxTokens, builder: (column) => column);

  GeneratedColumn<int> get tokenBuffer => $composableBuilder(
    column: $table.tokenBuffer,
    builder: (column) => column,
  );

  GeneratedColumn<int> get randomSeed => $composableBuilder(
    column: $table.randomSeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredBackend => $composableBuilder(
    column: $table.preferredBackend,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$ModelsTableTableManager
    extends
        RootTableManager<
          _$GenaDatabase,
          $ModelsTable,
          Model,
          $$ModelsTableFilterComposer,
          $$ModelsTableOrderingComposer,
          $$ModelsTableAnnotationComposer,
          $$ModelsTableCreateCompanionBuilder,
          $$ModelsTableUpdateCompanionBuilder,
          (Model, BaseReferences<_$GenaDatabase, $ModelsTable, Model>),
          Model,
          PrefetchHooks Function()
        > {
  $$ModelsTableTableManager(_$GenaDatabase db, $ModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> apiUrl = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                Value<String> modelType = const Value.absent(),
                Value<bool> supportImage = const Value.absent(),
                Value<bool> supportAudio = const Value.absent(),
                Value<bool> supportsFunctionCalls = const Value.absent(),
                Value<bool> isThinking = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<int> topK = const Value.absent(),
                Value<double> topP = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<int> tokenBuffer = const Value.absent(),
                Value<int> randomSeed = const Value.absent(),
                Value<String> preferredBackend = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> source = const Value.absent(),
              }) => ModelsCompanion(
                id: id,
                createdAt: createdAt,
                name: name,
                description: description,
                modelId: modelId,
                provider: provider,
                apiUrl: apiUrl,
                apiToken: apiToken,
                modelType: modelType,
                supportImage: supportImage,
                supportAudio: supportAudio,
                supportsFunctionCalls: supportsFunctionCalls,
                isThinking: isThinking,
                temperature: temperature,
                topK: topK,
                topP: topP,
                maxTokens: maxTokens,
                tokenBuffer: tokenBuffer,
                randomSeed: randomSeed,
                preferredBackend: preferredBackend,
                sourceType: sourceType,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required String name,
                required String description,
                Value<String?> modelId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> apiUrl = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                required String modelType,
                Value<bool> supportImage = const Value.absent(),
                Value<bool> supportAudio = const Value.absent(),
                Value<bool> supportsFunctionCalls = const Value.absent(),
                Value<bool> isThinking = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<int> topK = const Value.absent(),
                Value<double> topP = const Value.absent(),
                Value<int> maxTokens = const Value.absent(),
                Value<int> tokenBuffer = const Value.absent(),
                Value<int> randomSeed = const Value.absent(),
                Value<String> preferredBackend = const Value.absent(),
                required String sourceType,
                required String source,
              }) => ModelsCompanion.insert(
                id: id,
                createdAt: createdAt,
                name: name,
                description: description,
                modelId: modelId,
                provider: provider,
                apiUrl: apiUrl,
                apiToken: apiToken,
                modelType: modelType,
                supportImage: supportImage,
                supportAudio: supportAudio,
                supportsFunctionCalls: supportsFunctionCalls,
                isThinking: isThinking,
                temperature: temperature,
                topK: topK,
                topP: topP,
                maxTokens: maxTokens,
                tokenBuffer: tokenBuffer,
                randomSeed: randomSeed,
                preferredBackend: preferredBackend,
                sourceType: sourceType,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$GenaDatabase,
      $ModelsTable,
      Model,
      $$ModelsTableFilterComposer,
      $$ModelsTableOrderingComposer,
      $$ModelsTableAnnotationComposer,
      $$ModelsTableCreateCompanionBuilder,
      $$ModelsTableUpdateCompanionBuilder,
      (Model, BaseReferences<_$GenaDatabase, $ModelsTable, Model>),
      Model,
      PrefetchHooks Function()
    >;

class $GenaDatabaseManager {
  final _$GenaDatabase _db;
  $GenaDatabaseManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
  $$WorkspaceDocumentsTableTableManager get workspaceDocuments =>
      $$WorkspaceDocumentsTableTableManager(_db, _db.workspaceDocuments);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
}
