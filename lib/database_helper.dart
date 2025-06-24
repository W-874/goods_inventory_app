// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'data_class.dart';
import 'db_constants.dart';

class DatabaseHelper {
  static const _databaseName = "MyInventory.db";
  static const _databaseVersion = 3;

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
          $columnPrice REAL, 
          $columnDescription TEXT
        )
      ''');
      batch.execute('''
        CREATE TABLE $tableRawMaterials (
          $columnRawMaterialId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnRawMaterialRemainingQuantity INTEGER NOT NULL,
          $columnPrice REAL, 
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
    if (oldVersion < 3 && oldVersion > 0) {
      // Add any future migrations here
      await db.execute('ALTER TABLE $tableGoods RENAME TO ${tableGoods}_old;');
      await db.execute('ALTER TABLE $tableRawMaterials RENAME TO ${tableRawMaterials}_old;');
      batch.execute('''
        CREATE TABLE $tableGoods (
          $columnGoodsId INTEGER PRIMARY KEY AUTOINCREMENT, 
          $columnName TEXT NOT NULL,
          $columnGoodsRemainingQuantity INTEGER NOT NULL,
          $columnPrice REAL, 
          $columnDescription TEXT
        )
        CREATE TABLE $tableRawMaterials (
          $columnRawMaterialId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnName TEXT NOT NULL,
          $columnRawMaterialRemainingQuantity INTEGER NOT NULL,
          $columnPrice REAL, 
          $columnDescription TEXT
        )
      ''');
      await db.execute('''
        INSERT INTO $tableGoods (
          $columnGoodsId, $columnName, $columnGoodsRemainingQuantity, $columnPrice, $columnDescription
        )
        SELECT
          $columnGoodsId, $columnName, $columnGoodsRemainingQuantity, $columnPrice, $columnDescription
        FROM ${tableGoods}_old;
      ''');
      await db.execute('''
        INSERT INTO $tableRawMaterials (
          $columnRawMaterialId, $columnName, $columnRawMaterialRemainingQuantity, $columnPrice, $columnDescription
        )
        SELECT
          $columnRawMaterialId, $columnName, $columnRawMaterialRemainingQuantity, $columnPrice, $columnDescription
        FROM ${tableRawMaterials}_old;
      ''');
      await db.execute('DROP TABLE ${tableGoods}_old;');
      await db.execute('DROP TABLE ${tableRawMaterials}_old;');      
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

  /// Updates a Good and replaces its entire Bill of Materials in a single transaction.
  Future<void> updateGoodAndBOM(Goods good, List<BillOfMaterialEntry> bomEntries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Update the good itself
      await txn.update(tableGoods, good.toMap(), where: '$columnGoodsId = ?', whereArgs: [good.goodsID]);
      
      // 2. Delete all old BOM entries for this good
      await txn.delete(tableBillOfMaterials, where: '$columnGoodsId = ?', whereArgs: [good.goodsID]);

      // 3. Insert all the new BOM entries
      for (final entry in bomEntries) {
        await txn.insert(tableBillOfMaterials, entry.toMap());
      }
    });
  }

  Future<List<BillOfMaterialEntry>> getBillOfMaterialEntriesForRawMaterial(int rawMaterialId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBillOfMaterials,
      where: '$columnRawMaterialId = ?',
      whereArgs: [rawMaterialId],
    );
    return List.generate(maps.length, (i) {
      return BillOfMaterialEntry.fromMap(maps[i]);
    });
  }

  /// Updates a RawMaterial and replaces all BOM entries it's a part of.
  Future<void> updateRawMaterialAndBOM(RawMaterials material, List<BillOfMaterialEntry> bomEntries) async {
      final db = await instance.database;
      await db.transaction((txn) async {
          // 1. Update the raw material
          await txn.update(tableRawMaterials, material.toMap(), where: '$columnRawMaterialId = ?', whereArgs: [material.materialID]);

          // 2. Delete all old BOM entries for this material
          await txn.delete(tableBillOfMaterials, where: '$columnRawMaterialId = ?', whereArgs: [material.materialID]);

          // 3. Insert all the new BOM entries
          for (final entry in bomEntries) {
              await txn.insert(tableBillOfMaterials, entry.toMap());
          }
      });
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

  /// When production is completed, we update the pending good's status to 0.
  Future<void> completeProduction(PendingGood pendingGood) async {
    final db = await instance.database;
    // The transaction now only performs a single action.
    await db.transaction((txn) async {
        // Update the status to 0 (completed). The quantity no longer goes to the Goods table.
        await txn.update(
            tablePendingGoods,
            {columnStatus: 0},
            where: '$columnPendingId = ?',
            whereArgs: [pendingGood.pendingId],
        );
    });
  }

  Future<List<PendingGood>> getAllInStoreGoods() async {
    Database db = await instance.database;
    final String query = '''
      SELECT
        pg.$columnPendingId, pg.$columnGoodsId, pg.$columnQuantityInProduction, 
        pg.$columnStartDate, pg.$columnStatus, g.$columnName
      FROM
        $tablePendingGoods pg
      JOIN
        $tableGoods g ON pg.$columnGoodsId = g.$columnGoodsId
      WHERE
        pg.$columnStatus = 0
      ORDER BY pg.$columnStartDate DESC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return List.generate(maps.length, (i) => PendingGood.fromMap(maps[i]));
  }
  
  Future<void> stockInStoreGood(PendingGood completedGood) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Get the corresponding Good to update its stock
      final goodMaps = await txn.query(
        tableGoods,
        where: '$columnGoodsId = ?',
        whereArgs: [completedGood.goodsId],
      );
      if (goodMaps.isEmpty) {
        throw Exception("Cannot find corresponding good to stock this item into.");
      }
      final good = Goods.fromMap(goodMaps.first);

      // 2. Add the quantity to the existing good's stock
      await txn.update(
        tableGoods,
        {columnGoodsRemainingQuantity: good.quality + completedGood.quantityInProduction},
        where: '$columnGoodsId = ?',
        whereArgs: [good.goodsID],
      );

      // 3. Delete the record from the pending_goods table as it is now fully stocked.
      await txn.delete(
        tablePendingGoods,
        where: '$columnPendingId = ?',
        whereArgs: [completedGood.pendingId],
      );
    });
  }
  
  Future<int> deletePendingGood(int pendingId) async {
    final db = await instance.database;
    return await db.delete(
      tablePendingGoods,
      where: '$columnPendingId = ?',
      whereArgs: [pendingId],
    );
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
      
      await deletePendingGood(pendingGood.pendingId!);
    });
  }
}
