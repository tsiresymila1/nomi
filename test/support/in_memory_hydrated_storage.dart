import 'package:hydrated_bloc/hydrated_bloc.dart';

/// Minimal in-memory [Storage] for exercising [HydratedCubit]s in tests
/// without touching Hive or the filesystem.
class InMemoryHydratedStorage implements Storage {
  final Map<String, dynamic> _store = <String, dynamic>{};

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}
