import 'package:drift/drift.dart';
part 'gena_database.g.dart';

mixin TableMixin on Table {
  late final id = integer().autoIncrement()();
  late final createdAt = dateTime().withDefault(currentDateAndTime)();
}

class Chats extends Table with TableMixin {
  late final title = text().withLength(min: 6, max: 32)();
}

class Messages extends Table with TableMixin {
  late final chat = integer().references(Chats, #id)();
  late final role = text()();
  late final kind = text().withDefault(const Constant('text'))();
  late final content = text()();
  late final mediaPath = text().nullable()();
}

class Models extends Table with TableMixin {
  late final name = text().withLength(min: 1, max: 64)();
  late final description = text()();
  late final modelId = text().nullable()();
  late final modelType = text()();
  late final supportImage = boolean().withDefault(const Constant(false))();
  late final supportAudio = boolean().withDefault(const Constant(false))();
  late final supportsFunctionCalls = boolean().withDefault(
    const Constant(false),
  )();
  late final isThinking = boolean().withDefault(const Constant(false))();
  late final sourceType = text()();
  late final source = text()();
}

@DriftDatabase(tables: [Chats, Messages, Models])
class GenaDatabase extends _$GenaDatabase {
  GenaDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(models);
      }
      if (from < 3) {
        await m.addColumn(messages, messages.kind);
        await m.addColumn(messages, messages.mediaPath);
      }
      if (from < 4) {
        await m.addColumn(models, models.supportImage);
        await m.addColumn(models, models.supportAudio);
        await m.addColumn(models, models.supportsFunctionCalls);
        await m.addColumn(models, models.isThinking);
      }
      if (from < 5) {
        await m.addColumn(models, models.modelId);
      }
    },
  );
}
