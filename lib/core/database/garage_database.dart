import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GarageDatabase {
  final DatabaseFactory _factory;
  final String? databasePath;

  Database? _database;

  GarageDatabase({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;

  Future<Database> get instance async {
    final current = _database;
    if (current != null) return current;

    final path =
        databasePath ??
        p.join(await _factory.getDatabasesPath(), 'garage_finder.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE garages (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              address TEXT NOT NULL,
              phone TEXT NOT NULL,
              chief TEXT NOT NULL,
              specialty TEXT NOT NULL,
              imageUrl TEXT NOT NULL,
              city TEXT NOT NULL,
              openingHours TEXT NOT NULL,
              description TEXT NOT NULL,
              sourceUrl TEXT NOT NULL,
              rating REAL NOT NULL,
              reviewCount INTEGER NOT NULL,
              distanceKm REAL NOT NULL,
              isOpen INTEGER NOT NULL,
              availabilityStatus TEXT NOT NULL DEFAULT 'available',
              availabilityUpdatedAt TEXT,
              isVerified INTEGER NOT NULL,
              reviewStatus TEXT NOT NULL DEFAULT 'pending',
              distanceKnown INTEGER NOT NULL DEFAULT 1,
              responseTime TEXT NOT NULL,
              priceLevel TEXT NOT NULL,
              services TEXT NOT NULL,
              latitude REAL,
              longitude REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE favorite_garages (
              garageId TEXT PRIMARY KEY,
              createdAt INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_garages_city ON garages(city)');
          await db.execute(
            'CREATE INDEX idx_garages_specialty ON garages(specialty)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE garages ADD COLUMN reviewStatus TEXT NOT NULL DEFAULT 'pending'",
            );
            await db.execute('''
              UPDATE garages
              SET reviewStatus = CASE WHEN isVerified = 1 THEN 'approved' ELSE 'pending' END
            ''');
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE garages ADD COLUMN distanceKnown INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (oldVersion < 4) {
            await db.execute(
              "ALTER TABLE garages ADD COLUMN availabilityStatus TEXT NOT NULL DEFAULT 'available'",
            );
            await db.execute(
              'ALTER TABLE garages ADD COLUMN availabilityUpdatedAt TEXT',
            );
          }
        },
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    final current = _database;
    if (current == null) return;
    await current.close();
    _database = null;
  }
}
