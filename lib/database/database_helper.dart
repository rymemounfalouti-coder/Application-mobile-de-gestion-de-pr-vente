import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'prevente.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onOpen: (db) async {
        await _onCreate(db, 1);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute("DROP TABLE IF EXISTS users");
        await db.execute("DROP TABLE IF EXISTS clients");
        await db.execute("DROP TABLE IF EXISTS categories");
        await db.execute("DROP TABLE IF EXISTS produits");
        await db.execute("DROP TABLE IF EXISTS factures");
        await db.execute("DROP TABLE IF EXISTS details_facture");

        await _onCreate(db, newVersion);
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT,
        prenom TEXT,
        email TEXT,
        password TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT,
        token TEXT,
        expires_at TEXT,
        used_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_client TEXT,
        prenom_client TEXT,
        email TEXT,
        ville TEXT,
        categorie TEXT,
        statut TEXT,
        adresse TEXT,
        telephone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom_cat TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cat INTEGER,
        nom_produit TEXT,
        prix REAL,
        reference TEXT,
        stock INTEGER,
        categorie TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS factures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_client INTEGER,
        date TEXT,
        total REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS details_facture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_fact INTEGER,
        id_prod INTEGER,
        qte INTEGER,
        prix_vendu REAL
      )
    ''');
  }

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;
    return await db.query(table);
  }
}
