// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ArchivedMessagesTable extends ArchivedMessages
    with TableInfo<$ArchivedMessagesTable, ArchivedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchivedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    messageId,
    json,
    date,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archived_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArchivedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, messageId};
  @override
  ArchivedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchivedMessage(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ArchivedMessagesTable createAlias(String alias) {
    return $ArchivedMessagesTable(attachedDatabase, alias);
  }
}

class ArchivedMessage extends DataClass implements Insertable<ArchivedMessage> {
  final int chatId;
  final int messageId;
  final String json;
  final int date;
  final int? deletedAt;
  const ArchivedMessage({
    required this.chatId,
    required this.messageId,
    required this.json,
    required this.date,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['json'] = Variable<String>(json);
    map['date'] = Variable<int>(date);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ArchivedMessagesCompanion toCompanion(bool nullToAbsent) {
    return ArchivedMessagesCompanion(
      chatId: Value(chatId),
      messageId: Value(messageId),
      json: Value(json),
      date: Value(date),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ArchivedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchivedMessage(
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      json: serializer.fromJson<String>(json['json']),
      date: serializer.fromJson<int>(json['date']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'json': serializer.toJson<String>(json),
      'date': serializer.toJson<int>(date),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  ArchivedMessage copyWith({
    int? chatId,
    int? messageId,
    String? json,
    int? date,
    Value<int?> deletedAt = const Value.absent(),
  }) => ArchivedMessage(
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    json: json ?? this.json,
    date: date ?? this.date,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ArchivedMessage copyWithCompanion(ArchivedMessagesCompanion data) {
    return ArchivedMessage(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      json: data.json.present ? data.json.value : this.json,
      date: data.date.present ? data.date.value : this.date,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArchivedMessage(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('json: $json, ')
          ..write('date: $date, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, messageId, json, date, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchivedMessage &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.json == this.json &&
          other.date == this.date &&
          other.deletedAt == this.deletedAt);
}

class ArchivedMessagesCompanion extends UpdateCompanion<ArchivedMessage> {
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<String> json;
  final Value<int> date;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const ArchivedMessagesCompanion({
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.json = const Value.absent(),
    this.date = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArchivedMessagesCompanion.insert({
    required int chatId,
    required int messageId,
    required String json,
    required int date,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       json = Value(json),
       date = Value(date);
  static Insertable<ArchivedMessage> custom({
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<String>? json,
    Expression<int>? date,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (json != null) 'json': json,
      if (date != null) 'date': date,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArchivedMessagesCompanion copyWith({
    Value<int>? chatId,
    Value<int>? messageId,
    Value<String>? json,
    Value<int>? date,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ArchivedMessagesCompanion(
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      json: json ?? this.json,
      date: date ?? this.date,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchivedMessagesCompanion(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('json: $json, ')
          ..write('date: $date, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageEditsTable extends MessageEdits
    with TableInfo<$MessageEditsTable, MessageEdit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageEditsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<int> editedAt = GeneratedColumn<int>(
    'edited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, chatId, messageId, body, editedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_edits';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageEdit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_editedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageEdit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageEdit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edited_at'],
      )!,
    );
  }

  @override
  $MessageEditsTable createAlias(String alias) {
    return $MessageEditsTable(attachedDatabase, alias);
  }
}

class MessageEdit extends DataClass implements Insertable<MessageEdit> {
  final int id;
  final int chatId;
  final int messageId;
  final String body;
  final int editedAt;
  const MessageEdit({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.body,
    required this.editedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['body'] = Variable<String>(body);
    map['edited_at'] = Variable<int>(editedAt);
    return map;
  }

  MessageEditsCompanion toCompanion(bool nullToAbsent) {
    return MessageEditsCompanion(
      id: Value(id),
      chatId: Value(chatId),
      messageId: Value(messageId),
      body: Value(body),
      editedAt: Value(editedAt),
    );
  }

  factory MessageEdit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageEdit(
      id: serializer.fromJson<int>(json['id']),
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      body: serializer.fromJson<String>(json['body']),
      editedAt: serializer.fromJson<int>(json['editedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'body': serializer.toJson<String>(body),
      'editedAt': serializer.toJson<int>(editedAt),
    };
  }

  MessageEdit copyWith({
    int? id,
    int? chatId,
    int? messageId,
    String? body,
    int? editedAt,
  }) => MessageEdit(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    body: body ?? this.body,
    editedAt: editedAt ?? this.editedAt,
  );
  MessageEdit copyWithCompanion(MessageEditsCompanion data) {
    return MessageEdit(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      body: data.body.present ? data.body.value : this.body,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageEdit(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('editedAt: $editedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chatId, messageId, body, editedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEdit &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.body == this.body &&
          other.editedAt == this.editedAt);
}

class MessageEditsCompanion extends UpdateCompanion<MessageEdit> {
  final Value<int> id;
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<String> body;
  final Value<int> editedAt;
  const MessageEditsCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.body = const Value.absent(),
    this.editedAt = const Value.absent(),
  });
  MessageEditsCompanion.insert({
    this.id = const Value.absent(),
    required int chatId,
    required int messageId,
    required String body,
    required int editedAt,
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       body = Value(body),
       editedAt = Value(editedAt);
  static Insertable<MessageEdit> custom({
    Expression<int>? id,
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<String>? body,
    Expression<int>? editedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (body != null) 'body': body,
      if (editedAt != null) 'edited_at': editedAt,
    });
  }

  MessageEditsCompanion copyWith({
    Value<int>? id,
    Value<int>? chatId,
    Value<int>? messageId,
    Value<String>? body,
    Value<int>? editedAt,
  }) {
    return MessageEditsCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      body: body ?? this.body,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<int>(editedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageEditsCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('editedAt: $editedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $ArchivedMessagesTable archivedMessages = $ArchivedMessagesTable(
    this,
  );
  late final $MessageEditsTable messageEdits = $MessageEditsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    archivedMessages,
    messageEdits,
  ];
}

typedef $$ArchivedMessagesTableCreateCompanionBuilder =
    ArchivedMessagesCompanion Function({
      required int chatId,
      required int messageId,
      required String json,
      required int date,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$ArchivedMessagesTableUpdateCompanionBuilder =
    ArchivedMessagesCompanion Function({
      Value<int> chatId,
      Value<int> messageId,
      Value<String> json,
      Value<int> date,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$ArchivedMessagesTableFilterComposer
    extends Composer<_$AppDb, $ArchivedMessagesTable> {
  $$ArchivedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArchivedMessagesTableOrderingComposer
    extends Composer<_$AppDb, $ArchivedMessagesTable> {
  $$ArchivedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArchivedMessagesTableAnnotationComposer
    extends Composer<_$AppDb, $ArchivedMessagesTable> {
  $$ArchivedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ArchivedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ArchivedMessagesTable,
          ArchivedMessage,
          $$ArchivedMessagesTableFilterComposer,
          $$ArchivedMessagesTableOrderingComposer,
          $$ArchivedMessagesTableAnnotationComposer,
          $$ArchivedMessagesTableCreateCompanionBuilder,
          $$ArchivedMessagesTableUpdateCompanionBuilder,
          (
            ArchivedMessage,
            BaseReferences<_$AppDb, $ArchivedMessagesTable, ArchivedMessage>,
          ),
          ArchivedMessage,
          PrefetchHooks Function()
        > {
  $$ArchivedMessagesTableTableManager(_$AppDb db, $ArchivedMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArchivedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArchivedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArchivedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArchivedMessagesCompanion(
                chatId: chatId,
                messageId: messageId,
                json: json,
                date: date,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chatId,
                required int messageId,
                required String json,
                required int date,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArchivedMessagesCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                json: json,
                date: date,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArchivedMessagesTable, ArchivedMessage>(table),
                  BaseReferences<
                    _$AppDb,
                    $ArchivedMessagesTable,
                    ArchivedMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArchivedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ArchivedMessagesTable,
      ArchivedMessage,
      $$ArchivedMessagesTableFilterComposer,
      $$ArchivedMessagesTableOrderingComposer,
      $$ArchivedMessagesTableAnnotationComposer,
      $$ArchivedMessagesTableCreateCompanionBuilder,
      $$ArchivedMessagesTableUpdateCompanionBuilder,
      (
        ArchivedMessage,
        BaseReferences<_$AppDb, $ArchivedMessagesTable, ArchivedMessage>,
      ),
      ArchivedMessage,
      PrefetchHooks Function()
    >;
typedef $$MessageEditsTableCreateCompanionBuilder =
    MessageEditsCompanion Function({
      Value<int> id,
      required int chatId,
      required int messageId,
      required String body,
      required int editedAt,
    });
typedef $$MessageEditsTableUpdateCompanionBuilder =
    MessageEditsCompanion Function({
      Value<int> id,
      Value<int> chatId,
      Value<int> messageId,
      Value<String> body,
      Value<int> editedAt,
    });

class $$MessageEditsTableFilterComposer
    extends Composer<_$AppDb, $MessageEditsTable> {
  $$MessageEditsTableFilterComposer({
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

  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageEditsTableOrderingComposer
    extends Composer<_$AppDb, $MessageEditsTable> {
  $$MessageEditsTableOrderingComposer({
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

  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageEditsTableAnnotationComposer
    extends Composer<_$AppDb, $MessageEditsTable> {
  $$MessageEditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);
}

class $$MessageEditsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $MessageEditsTable,
          MessageEdit,
          $$MessageEditsTableFilterComposer,
          $$MessageEditsTableOrderingComposer,
          $$MessageEditsTableAnnotationComposer,
          $$MessageEditsTableCreateCompanionBuilder,
          $$MessageEditsTableUpdateCompanionBuilder,
          (
            MessageEdit,
            BaseReferences<_$AppDb, $MessageEditsTable, MessageEdit>,
          ),
          MessageEdit,
          PrefetchHooks Function()
        > {
  $$MessageEditsTableTableManager(_$AppDb db, $MessageEditsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageEditsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageEditsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageEditsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> editedAt = const Value.absent(),
              }) => MessageEditsCompanion(
                id: id,
                chatId: chatId,
                messageId: messageId,
                body: body,
                editedAt: editedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int chatId,
                required int messageId,
                required String body,
                required int editedAt,
              }) => MessageEditsCompanion.insert(
                id: id,
                chatId: chatId,
                messageId: messageId,
                body: body,
                editedAt: editedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessageEditsTable, MessageEdit>(table),
                  BaseReferences<_$AppDb, $MessageEditsTable, MessageEdit>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageEditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $MessageEditsTable,
      MessageEdit,
      $$MessageEditsTableFilterComposer,
      $$MessageEditsTableOrderingComposer,
      $$MessageEditsTableAnnotationComposer,
      $$MessageEditsTableCreateCompanionBuilder,
      $$MessageEditsTableUpdateCompanionBuilder,
      (MessageEdit, BaseReferences<_$AppDb, $MessageEditsTable, MessageEdit>),
      MessageEdit,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$ArchivedMessagesTableTableManager get archivedMessages =>
      $$ArchivedMessagesTableTableManager(_db, _db.archivedMessages);
  $$MessageEditsTableTableManager get messageEdits =>
      $$MessageEditsTableTableManager(_db, _db.messageEdits);
}
