import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart';

final genaDatabaseProvider = Provider<GenaDatabase>((ref) {
  final database = GenaDatabase(driftDatabase(name: 'gena'));
  ref.onDispose(database.close);
  return database;
});
