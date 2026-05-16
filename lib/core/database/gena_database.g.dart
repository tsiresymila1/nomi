// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gena_database.dart';

// ignore_for_file: type=lint
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
  List<GeneratedColumn> get $columns => [id, createdAt, title];
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
  final String title;
  const Chat({required this.id, required this.createdAt, required this.title});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['title'] = Variable<String>(title);
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
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
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'title': serializer.toJson<String>(title),
    };
  }

  Chat copyWith({int? id, DateTime? createdAt, String? title}) => Chat(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    title: title ?? this.title,
  );
  Chat copyWithCompanion(ChatsCompanion data) {
    return Chat(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chat(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.title == this.title);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> title;
  const ChatsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
  });
  ChatsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String title,
  }) : title = Value(title);
  static Insertable<Chat> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (title != null) 'title': title,
    });
  }

  ChatsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? title,
  }) {
    return ChatsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
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
    modelType,
    supportImage,
    supportAudio,
    supportsFunctionCalls,
    isThinking,
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
  final String modelType;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final String sourceType;
  final String source;
  const Model({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.description,
    this.modelId,
    required this.modelType,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.isThinking,
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
    map['model_type'] = Variable<String>(modelType);
    map['support_image'] = Variable<bool>(supportImage);
    map['support_audio'] = Variable<bool>(supportAudio);
    map['supports_function_calls'] = Variable<bool>(supportsFunctionCalls);
    map['is_thinking'] = Variable<bool>(isThinking);
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
      modelType: Value(modelType),
      supportImage: Value(supportImage),
      supportAudio: Value(supportAudio),
      supportsFunctionCalls: Value(supportsFunctionCalls),
      isThinking: Value(isThinking),
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
      modelType: serializer.fromJson<String>(json['modelType']),
      supportImage: serializer.fromJson<bool>(json['supportImage']),
      supportAudio: serializer.fromJson<bool>(json['supportAudio']),
      supportsFunctionCalls: serializer.fromJson<bool>(
        json['supportsFunctionCalls'],
      ),
      isThinking: serializer.fromJson<bool>(json['isThinking']),
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
      'modelType': serializer.toJson<String>(modelType),
      'supportImage': serializer.toJson<bool>(supportImage),
      'supportAudio': serializer.toJson<bool>(supportAudio),
      'supportsFunctionCalls': serializer.toJson<bool>(supportsFunctionCalls),
      'isThinking': serializer.toJson<bool>(isThinking),
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
    String? modelType,
    bool? supportImage,
    bool? supportAudio,
    bool? supportsFunctionCalls,
    bool? isThinking,
    String? sourceType,
    String? source,
  }) => Model(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    name: name ?? this.name,
    description: description ?? this.description,
    modelId: modelId.present ? modelId.value : this.modelId,
    modelType: modelType ?? this.modelType,
    supportImage: supportImage ?? this.supportImage,
    supportAudio: supportAudio ?? this.supportAudio,
    supportsFunctionCalls: supportsFunctionCalls ?? this.supportsFunctionCalls,
    isThinking: isThinking ?? this.isThinking,
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
          ..write('modelType: $modelType, ')
          ..write('supportImage: $supportImage, ')
          ..write('supportAudio: $supportAudio, ')
          ..write('supportsFunctionCalls: $supportsFunctionCalls, ')
          ..write('isThinking: $isThinking, ')
          ..write('sourceType: $sourceType, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    name,
    description,
    modelId,
    modelType,
    supportImage,
    supportAudio,
    supportsFunctionCalls,
    isThinking,
    sourceType,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.name == this.name &&
          other.description == this.description &&
          other.modelId == this.modelId &&
          other.modelType == this.modelType &&
          other.supportImage == this.supportImage &&
          other.supportAudio == this.supportAudio &&
          other.supportsFunctionCalls == this.supportsFunctionCalls &&
          other.isThinking == this.isThinking &&
          other.sourceType == this.sourceType &&
          other.source == this.source);
}

class ModelsCompanion extends UpdateCompanion<Model> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> name;
  final Value<String> description;
  final Value<String?> modelId;
  final Value<String> modelType;
  final Value<bool> supportImage;
  final Value<bool> supportAudio;
  final Value<bool> supportsFunctionCalls;
  final Value<bool> isThinking;
  final Value<String> sourceType;
  final Value<String> source;
  const ModelsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelType = const Value.absent(),
    this.supportImage = const Value.absent(),
    this.supportAudio = const Value.absent(),
    this.supportsFunctionCalls = const Value.absent(),
    this.isThinking = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.source = const Value.absent(),
  });
  ModelsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String name,
    required String description,
    this.modelId = const Value.absent(),
    required String modelType,
    this.supportImage = const Value.absent(),
    this.supportAudio = const Value.absent(),
    this.supportsFunctionCalls = const Value.absent(),
    this.isThinking = const Value.absent(),
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
    Expression<String>? modelType,
    Expression<bool>? supportImage,
    Expression<bool>? supportAudio,
    Expression<bool>? supportsFunctionCalls,
    Expression<bool>? isThinking,
    Expression<String>? sourceType,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (modelId != null) 'model_id': modelId,
      if (modelType != null) 'model_type': modelType,
      if (supportImage != null) 'support_image': supportImage,
      if (supportAudio != null) 'support_audio': supportAudio,
      if (supportsFunctionCalls != null)
        'supports_function_calls': supportsFunctionCalls,
      if (isThinking != null) 'is_thinking': isThinking,
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
    Value<String>? modelType,
    Value<bool>? supportImage,
    Value<bool>? supportAudio,
    Value<bool>? supportsFunctionCalls,
    Value<bool>? isThinking,
    Value<String>? sourceType,
    Value<String>? source,
  }) {
    return ModelsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      description: description ?? this.description,
      modelId: modelId ?? this.modelId,
      modelType: modelType ?? this.modelType,
      supportImage: supportImage ?? this.supportImage,
      supportAudio: supportAudio ?? this.supportAudio,
      supportsFunctionCalls:
          supportsFunctionCalls ?? this.supportsFunctionCalls,
      isThinking: isThinking ?? this.isThinking,
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
          ..write('modelType: $modelType, ')
          ..write('supportImage: $supportImage, ')
          ..write('supportAudio: $supportAudio, ')
          ..write('supportsFunctionCalls: $supportsFunctionCalls, ')
          ..write('isThinking: $isThinking, ')
          ..write('sourceType: $sourceType, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

abstract class _$GenaDatabase extends GeneratedDatabase {
  _$GenaDatabase(QueryExecutor e) : super(e);
  $GenaDatabaseManager get managers => $GenaDatabaseManager(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ModelsTable models = $ModelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [chats, messages, models];
}

typedef $$ChatsTableCreateCompanionBuilder =
    ChatsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      required String title,
    });
typedef $$ChatsTableUpdateCompanionBuilder =
    ChatsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> title,
    });

final class $$ChatsTableReferences
    extends BaseReferences<_$GenaDatabase, $ChatsTable, Chat> {
  $$ChatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

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
          PrefetchHooks Function({bool messagesRefs})
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
                Value<String> title = const Value.absent(),
              }) => ChatsCompanion(id: id, createdAt: createdAt, title: title),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                required String title,
              }) => ChatsCompanion.insert(
                id: id,
                createdAt: createdAt,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ChatsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins: null,
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
      PrefetchHooks Function({bool messagesRefs})
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
      required String modelType,
      Value<bool> supportImage,
      Value<bool> supportAudio,
      Value<bool> supportsFunctionCalls,
      Value<bool> isThinking,
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
      Value<String> modelType,
      Value<bool> supportImage,
      Value<bool> supportAudio,
      Value<bool> supportsFunctionCalls,
      Value<bool> isThinking,
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
                Value<String> modelType = const Value.absent(),
                Value<bool> supportImage = const Value.absent(),
                Value<bool> supportAudio = const Value.absent(),
                Value<bool> supportsFunctionCalls = const Value.absent(),
                Value<bool> isThinking = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> source = const Value.absent(),
              }) => ModelsCompanion(
                id: id,
                createdAt: createdAt,
                name: name,
                description: description,
                modelId: modelId,
                modelType: modelType,
                supportImage: supportImage,
                supportAudio: supportAudio,
                supportsFunctionCalls: supportsFunctionCalls,
                isThinking: isThinking,
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
                required String modelType,
                Value<bool> supportImage = const Value.absent(),
                Value<bool> supportAudio = const Value.absent(),
                Value<bool> supportsFunctionCalls = const Value.absent(),
                Value<bool> isThinking = const Value.absent(),
                required String sourceType,
                required String source,
              }) => ModelsCompanion.insert(
                id: id,
                createdAt: createdAt,
                name: name,
                description: description,
                modelId: modelId,
                modelType: modelType,
                supportImage: supportImage,
                supportAudio: supportAudio,
                supportsFunctionCalls: supportsFunctionCalls,
                isThinking: isThinking,
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
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
}
