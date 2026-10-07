import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/core/database/garage_database.dart';
import 'package:garage_finder/data/garage_data.dart';
import 'package:garage_finder/repositories/garage_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late GarageDatabase database;
  late SqfliteGarageRepository repository;

  setUpAll(() => sqfliteFfiInit());

  setUp(() {
    database = GarageDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SqfliteGarageRepository(database);
  });

  tearDown(() => database.close());

  test('SQLite repository inserts and reads seeded garages', () async {
    await repository.seedIfEmpty(garages.take(2).toList());
    expect(await repository.getGarages(), hasLength(2));
  });

  test('seeding does not overwrite existing database contents', () async {
    await repository.seedIfEmpty(garages.take(1).toList());
    await repository.seedIfEmpty(garages.skip(1).take(2).toList());
    expect((await repository.getGarages()).single.id, garages.first.id);
  });

  test('favorite add and remove persist in SQLite', () async {
    final id = garages.first.id;
    await repository.setFavorite(id, true);
    expect(await repository.getFavoriteIds(), contains(id));
    await repository.setFavorite(id, false);
    expect(await repository.getFavoriteIds(), isEmpty);
  });
}
