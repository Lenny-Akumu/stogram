import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_db.g.dart';

/// Every message we have seen, raw TDLib JSON, so deletions can't erase it.
class ArchivedMessages extends Table {
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();
  TextColumn get json => text()();
  IntColumn get date => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {chatId, messageId};
}

class MessageEdits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();
  TextColumn get body => text()();
  IntColumn get editedAt => integer()();
}

@DriftDatabase(tables: [ArchivedMessages, MessageEdits])
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ayu'));

  @override
  int get schemaVersion => 1;
}
