import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data_class.dart';
import 'db_constants.dart';

class DatabaseHelper {
  static const _databaseName = "MyInventory.db";
  static const _databaseVersion = 2;

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Opens the database (and creates it if it doesn't exist)
  Future<Database> _initDB() async {
    // Initialize sqflite for FFI support
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
    } 
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  // Enable foreign keys
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Called if the database doesn't exist on disk.
  Future _onCreate(Database db, int version) async {
    // Since this is called only when the db is created, we can just
    // call our upgrade logic with an oldVersion of 0.
    await _onUpgrade(db, 0, version);
  }

  // Handles schema migrations
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    var batch = db.batch();
    if (oldVersion < 1) {
      // --- Version 1 Tables ---
      batch.execute('''
        CREATE TABLE $tableGoods (
          $columnGoodsId INTEGER PRIMARY KEY, 
          $columnName TEXT NOT NULL,
          $columnGoodsRemainingQuantity INTEGER NOT NULL,
          $columnPrice REAL NOT NULL, 
          $columnDescription TEXT
        )
      ''');
      batch.execute('''
        CREATE TABLE $tableRawMaterials (
          $columnRawMaterialId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnRawMaterialRemainingQuantity INTEGER NOT NULL,
          $columnPrice REAL NOT NULL, 
          $columnDescription TEXT
        )
      ''');
      batch.execute('''
        CREATE TABLE $tableBillOfMaterials (
          $columnGoodsId INTEGER NOT NULL,
          $columnRawMaterialId INTEGER NOT NULL,
          $columnQuantityNeeded INTEGER NOT NULL,
          PRIMARY KEY ($columnGoodsId, $columnRawMaterialId),
          FOREIGN KEY ($columnGoodsId) REFERENCES $tableGoods ($columnGoodsId) ON DELETE CASCADE,
          FOREIGN KEY ($columnRawMaterialId) REFERENCES $tableRawMaterials ($columnRawMaterialId) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 2) {
      // --- Version 2 Table ---
       batch.execute('''
        CREATE TABLE $tablePendingGoods (
          $columnPendingId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnGoodsId INTEGER NOT NULL,
          $columnQuantityInProduction INTEGER NOT NULL,
          $columnStartDate TEXT NOT NULL,
          $columnStatus INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY ($columnGoodsId) REFERENCES $tableGoods ($columnGoodsId) ON DELETE CASCADE
        )
      ''');
    }
    await batch.commit();
  }
  
  // --- Goods Table Operations ---
  Future<int> createGood(Goods good) async {
    Database db = await instance.database;
    return await db.insert(tableGoods, good.toMap(forInsertAndAutoincrement: true));
  }

  Future<Goods?> getGood(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Goods.fromMap(maps.first);
    return null;
  }

  Future<List<Goods>> getAllGoods() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableGoods);
    return List.generate(maps.length, (i) => Goods.fromMap(maps[i]));
  }

  Future<int> updateGood(Goods good) async {
    Database db = await instance.database;
    return await db.update(tableGoods, good.toMap(), where: '$columnGoodsId = ?', whereArgs: [good.goodsID]);
  }

  Future<int> deleteGood(int id) async {
    Database db = await instance.database;
    return await db.delete(tableGoods, where: '$columnGoodsId = ?', whereArgs: [id]);
  }

  // --- RawMaterials Table Operations ---
  Future<int> createRawMaterial(RawMaterials rawMaterial) async {
    Database db = await instance.database;
    return await db.insert(tableRawMaterials, rawMaterial.toMap(forInsertAndAutoincrement: true));
  }

  Future<RawMaterials?> getRawMaterial(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return RawMaterials.fromMap(maps.first);
    return null;
  }

  Future<List<RawMaterials>> getAllRawMaterials() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableRawMaterials);
    return List.generate(maps.length, (i) => RawMaterials.fromMap(maps[i]));
  }

  Future<int> updateRawMaterial(RawMaterials rawMaterial) async {
    Database db = await instance.database;
    return await db.update(tableRawMaterials, rawMaterial.toMap(), where: '$columnRawMaterialId = ?', whereArgs: [rawMaterial.materialID]);
  }

  Future<int> deleteRawMaterial(int id) async {
    Database db = await instance.database;
    return await db.delete(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [id]);
  }

  // --- BillOfMaterials Table Operations ---
  Future<List<BillOfMaterialEntry>> getBillOfMaterialEntriesForGood(int goodsId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableBillOfMaterials, where: '$columnGoodsId = ?', whereArgs: [goodsId]);
    return List.generate(maps.length, (i) => BillOfMaterialEntry.fromMap(maps[i]));
  }

  Future<List<BillOfMaterialEntry>> getBillOfMaterialsWithNames(int goodsId) async {
    Database db = await instance.database;
    final String query = '''
      SELECT bom.$columnGoodsId, bom.$columnRawMaterialId, bom.$columnQuantityNeeded, rm.$columnName
      FROM $tableBillOfMaterials bom JOIN $tableRawMaterials rm ON bom.$columnRawMaterialId = rm.$columnRawMaterialId
      WHERE bom.$columnGoodsId = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [goodsId]);
    return List.generate(maps.length, (i) => BillOfMaterialEntry.fromMap(maps[i]));
  }

  Future<List<Goods>> getGoodsUsingRawMaterial(int rawMaterialId) async {
    final db = await instance.database;
    final String query = '''
      SELECT g.* FROM $tableGoods g
      JOIN $tableBillOfMaterials bom ON g.$columnGoodsId = bom.$columnGoodsId
      WHERE bom.$columnRawMaterialId = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [rawMaterialId]);
    return List.generate(maps.length, (i) => Goods.fromMap(maps[i]));
  }


  // --- PendingGoods Table Operations ---

  Future<List<PendingGood>> getAllPendingGoods() async {
    Database db = await instance.database;
    final String query = '''
      SELECT pg.$columnPendingId, pg.$columnGoodsId, pg.$columnQuantityInProduction, pg.$columnStartDate, pg.$columnStatus, g.$columnName
      FROM $tablePendingGoods pg JOIN $tableGoods g ON pg.$columnGoodsId = g.$columnGoodsId
      WHERE pg.$columnStatus = 1
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return List.generate(maps.length, (i) => PendingGood.fromMap(maps[i]));
  }

  Future<void> startProduction(int goodsId, int quantityToProduce) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final bomMaps = await txn.query(tableBillOfMaterials, where: '$columnGoodsId = ?', whereArgs: [goodsId]);
      if (bomMaps.isEmpty) throw Exception("This good has no Bill of Materials defined.");
      final bomEntries = bomMaps.map((map) => BillOfMaterialEntry.fromMap(map)).toList();

      for (final entry in bomEntries) {
        final requiredQty = entry.quantityNeeded * quantityToProduce;
        final materialMaps = await txn.query(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
        final material = RawMaterials.fromMap(materialMaps.first);

        if (material.quality < requiredQty) throw Exception("Not enough ${material.name}. Required: $requiredQty, Available: ${material.quality}");
        
        await txn.update(tableRawMaterials, {columnRawMaterialRemainingQuantity: material.quality - requiredQty}, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
      }

      final pendingGood = PendingGood(
        goodsId: goodsId,
        quantityInProduction: quantityToProduce,
        startDate: DateTime.now(),
        isUnderConstruction: true,
      );
      await txn.insert(tablePendingGoods, pendingGood.toMap());
    });
  }

  Future<void> completeProduction(PendingGood pendingGood) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final goodMaps = await txn.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [pendingGood.goodsId]);
      if (goodMaps.isEmpty) throw Exception("Good not found.");
      final good = Goods.fromMap(goodMaps.first);

      await txn.update(tableGoods, {columnGoodsRemainingQuantity: good.quality + pendingGood.quantityInProduction}, where: '$columnGoodsId = ?', whereArgs: [pendingGood.goodsId]);
      
      await txn.update(tablePendingGoods, {columnStatus: 0}, where: '$columnPendingId = ?', whereArgs: [pendingGood.pendingId]);
    });
  }
  
  Future<void> cancelProduction(PendingGood pendingGood) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final bomMaps = await txn.query(tableBillOfMaterials, where: '$columnGoodsId = ?', whereArgs: [pendingGood.goodsId]);
      final bomEntries = bomMaps.map((map) => BillOfMaterialEntry.fromMap(map)).toList();

      for (final entry in bomEntries) {
        final consumedQty = entry.quantityNeeded * pendingGood.quantityInProduction;
        final materialMaps = await txn.query(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
        final material = RawMaterials.fromMap(materialMaps.first);
        await txn.update(tableRawMaterials, {columnRawMaterialRemainingQuantity: material.quality + consumedQty}, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
      }
      
      await txn.update(tablePendingGoods, {columnStatus: 0}, where: '$columnPendingId = ?', whereArgs: [pendingGood.pendingId]);
    });
  }
}
