// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'data_class.dart';
import 'db_constants.dart';
import 'models/models.dart';

class DatabaseHelper {
  static const _databaseName = "MyInventory.db";
  static const _databaseVersion = 6;

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
    if(!kIsWeb){
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } 
    }
    if(kIsWeb){
      databaseFactory = databaseFactoryFfiWeb;
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
          $columnDescription TEXT,
          $columnIsComponent INTEGER NOT NULL DEFAULT 0
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
    if (oldVersion < 5) {
      // Add the new table for Good-to-Good relationships
      await db.execute('''
        CREATE TABLE $tableGoodsBOM (
          $columnFinalGoodId INTEGER NOT NULL,
          $columnComponentGoodId INTEGER NOT NULL,
          $columnQuantityNeeded INTEGER NOT NULL,
          PRIMARY KEY ($columnFinalGoodId, $columnComponentGoodId),
          FOREIGN KEY ($columnFinalGoodId) REFERENCES $tableGoods ($columnGoodsId) ON DELETE CASCADE,
          FOREIGN KEY ($columnComponentGoodId) REFERENCES $tableGoods ($columnGoodsId) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion > 0 && oldVersion < 6) {
      // For existing users, add the new column to the goods table.
      // We default it to 0 (false) so existing goods are treated as final products.
      await db.execute('''
        ALTER TABLE $tableGoods ADD COLUMN $columnIsComponent INTEGER NOT NULL DEFAULT 0;
      ''');
    }
    await batch.commit();
  }
  
  // --- Goods Table Operations ---
  Future<int> createGood(Good good) async {
    Database db = await instance.database;
    return await db.insert(tableGoods, good.toMap(forInsertAndAutoincrement: true));
  }

  Future<Good?> getGood(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Good.fromMap(maps.first);
    return null;
  }

  Future<List<Good>> getAllGoods() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableGoods);
    return List.generate(maps.length, (i) => Good.fromMap(maps[i]));
  }

  Future<int> updateGood(Good good) async {
    Database db = await instance.database;
    return await db.update(tableGoods, good.toMap(), where: '$columnGoodsId = ?', whereArgs: [good.goodsId]);
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
  Future<List<BillOfMaterialEntry>> getRawMaterialBOMForGood(int goodsId) async {
    Database db = await instance.database;
    final String query = '''
      SELECT bom.$columnGoodsId, bom.$columnRawMaterialId, bom.$columnQuantityNeeded, rm.$columnName
      FROM $tableBillOfMaterials bom JOIN $tableRawMaterials rm ON bom.$columnRawMaterialId = rm.$columnRawMaterialId
      WHERE bom.$columnGoodsId = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [goodsId]);
    return List.generate(maps.length, (i) => BillOfMaterialEntry.fromMap(maps[i]));
  }

  Future<List<Good>> getGoodsUsingRawMaterial(int rawMaterialId) async {
    final db = await instance.database;
    final String query = '''
      SELECT g.* FROM $tableGoods g
      JOIN $tableBillOfMaterials bom ON g.$columnGoodsId = bom.$columnGoodsId
      WHERE bom.$columnRawMaterialId = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [rawMaterialId]);
    return List.generate(maps.length, (i) => Good.fromMap(maps[i]));
  }

  /// Updates a Good and replaces its entire Bill of Materials in a single transaction.
  Future<void> updateGoodAndBOM(Good good, List<BillOfMaterialEntry> materialBomEntries, List<GoodBOMEntry> goodBomEntries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Update the good itself
      await txn.update(
        tableGoods, 
        good.toMap(), 
        where: '$columnGoodsId = ?', 
        whereArgs: [good.goodsId]
      );
      
      await txn.delete(
        tableBillOfMaterials, 
        where: '$columnGoodsId = ?', 
        whereArgs: [good.goodsId]
      );
      await txn.delete(
        tableGoodsBOM, 
        where: '$columnFinalGoodId = ?', 
        whereArgs: [good.goodsId]
      );

      for (final entry in materialBomEntries) {
        await txn.insert(tableBillOfMaterials, entry.toMap());
      }
      for (final entry in goodBomEntries) {
        await txn.insert(tableGoodsBOM, entry.toMap());
      }
    });
  }

  Future<List<BillOfMaterialEntry>> getBillOfMaterialEntriesForRawMaterial(int rawMaterialId) async {
    Database db = await instance.database;
    final String query = '''
      SELECT
        bom.$columnGoodsId,
        bom.$columnRawMaterialId,
        bom.$columnQuantityNeeded,
        g.$columnName
      FROM
        $tableBillOfMaterials bom
      JOIN
        $tableGoods g ON bom.$columnGoodsId = g.$columnGoodsId
      WHERE
        bom.$columnRawMaterialId = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [rawMaterialId]);
    return List.generate(maps.length, (i) {
      return BillOfMaterialEntry.fromMap(maps[i]);
    });
  }

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

  /// New method to get the Good-to-Good BOM entries for a final product.
  Future<List<GoodBOMEntry>> getGoodsBOMForGood(int finalGoodId) async {
    final db = await instance.database;
    final String query = '''
      SELECT
        bom.$columnFinalGoodId,
        bom.$columnComponentGoodId,
        bom.$columnQuantityNeeded,
        g.$columnName
      FROM
        $tableGoodsBOM bom
      JOIN
        $tableGoods g ON bom.$columnComponentGoodId = g.$columnGoodsId
      WHERE
        bom.$columnFinalGoodId = ?
    ''';
    final maps = await db.rawQuery(query, [finalGoodId]);
    return List.generate(maps.length, (i) => GoodBOMEntry.fromMap(maps[i]));
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

      final rawMaterialBOMs = await txn.query(tableBillOfMaterials, where: '$columnGoodsId = ?', whereArgs: [goodsId]);
      final rawMaterialEntries = rawMaterialBOMs.map((map) => BillOfMaterialEntry.fromMap(map)).toList();
      final goodsBOMs = await txn.query(tableGoodsBOM, where: '$columnFinalGoodId = ?', whereArgs: [goodsId]);
      final goodBOMEntries = goodsBOMs.map((map) => GoodBOMEntry.fromMap(map)).toList();

      if (rawMaterialEntries.isEmpty && goodBOMEntries.isEmpty) {
        throw Exception("This good has no Bill of Materials defined.");
      }

      for (final entry in rawMaterialEntries) {
        final requiredQty = entry.quantityNeeded * quantityToProduce;
        final materialMaps = await txn.query(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
        final material = RawMaterials.fromMap(materialMaps.first);
        if (material.quality < requiredQty) throw Exception("Not enough ${material.name}. Required: $requiredQty, Available: ${material.quality}");
        await txn.update(tableRawMaterials, {columnRawMaterialRemainingQuantity: material.quality - requiredQty}, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
      }
      for (final entry in goodBOMEntries) {
        final requiredQty = entry.quantityNeeded * quantityToProduce;
        final goodMaps = await txn.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [entry.componentGoodId]);
        final componentGood = Good.fromMap(goodMaps.first);
        if (componentGood.quantity < requiredQty) throw Exception("Not enough ${componentGood.name}. Required: $requiredQty, Available: ${componentGood.quantity}");
        await txn.update(tableGoods, {columnGoodsRemainingQuantity: componentGood.quantity - requiredQty}, where: '$columnGoodsId = ?', whereArgs: [entry.componentGoodId]);
      }

      final pendingGood = PendingGood(goodsId: goodsId, quantityInProduction: quantityToProduce, startDate: DateTime.now(), isUnderConstruction: true);
      await txn.insert(tablePendingGoods, pendingGood.toMap());
    });
  }

  /// When production is completed, we update the pending good's status to 0.
  Future<void> completeProduction(PendingGood pendingGood) async {
    final db = await instance.database;
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
  
  Future<void> stockInStoreGood(PendingGood completedGood, int quantityToStock) async {
    if (quantityToStock <= 0) return;
    if (quantityToStock > completedGood.quantityInProduction) {
      throw Exception("Cannot stock more than what is in store.");
    }

    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Get the corresponding Good to update its stock
      final goodMaps = await txn.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [completedGood.goodsId]);
      if (goodMaps.isEmpty) throw Exception("Cannot find corresponding good to stock this item into.");
      final good = Good.fromMap(goodMaps.first);

      // 2. Add the quantity to the existing good's stock
      await txn.update(
        tableGoods,
        {columnGoodsRemainingQuantity: good.quantity + quantityToStock},
        where: '$columnGoodsId = ?',
        whereArgs: [good.goodsId],
      );

      // 3. Update or delete the record from the pending_goods table
      final newInStoreQuantity = completedGood.quantityInProduction - quantityToStock;
      if (newInStoreQuantity > 0) {
        // Just update the remaining quantity
        await txn.update(
            tablePendingGoods,
            {columnQuantityInProduction: newInStoreQuantity},
            where: '$columnPendingId = ?',
            whereArgs: [completedGood.pendingId],
        );
      } else {
        // The entire stock has been moved, so delete the record
        await txn.delete(
            tablePendingGoods,
            where: '$columnPendingId = ?',
            whereArgs: [completedGood.pendingId],
        );
      }
    });
  }

  Future<void> exportInStoreGood(PendingGood completedGood, int quantityToExport) async {
    if (quantityToExport <= 0) return;
    if (quantityToExport > completedGood.quantityInProduction) {
      throw Exception("Cannot export more than what is in store.");
    }
    
    final db = await instance.database;
    final newInStoreQuantity = completedGood.quantityInProduction - quantityToExport;

    if (newInStoreQuantity > 0) {
      await db.update(
          tablePendingGoods,
          {columnQuantityInProduction: newInStoreQuantity},
          where: '$columnPendingId = ?',
          whereArgs: [completedGood.pendingId],
      );
    } else {
      await db.delete(
          tablePendingGoods,
          where: '$columnPendingId = ?',
          whereArgs: [completedGood.pendingId],
      );
    }
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

    final rawMaterialBOMs = await txn.query(
      tableBillOfMaterials,
      where: '$columnGoodsId = ?',
      whereArgs: [pendingGood.goodsId],
    );
    final rawMaterialEntries = rawMaterialBOMs.map((map) => BillOfMaterialEntry.fromMap(map)).toList();
    for (final entry in rawMaterialEntries) {
      final consumedQty = entry.quantityNeeded * pendingGood.quantityInProduction;
      final materialMaps = await txn.query(tableRawMaterials, where: '$columnRawMaterialId = ?', whereArgs: [entry.rawMaterialId]);
      final material = RawMaterials.fromMap(materialMaps.first);
      
      await txn.update(
        tableRawMaterials,
        {columnRawMaterialRemainingQuantity: material.quality + consumedQty},
        where: '$columnRawMaterialId = ?',
        whereArgs: [entry.rawMaterialId],
      );
    }
    
    final goodsBOMs = await txn.query(
        tableGoodsBOM,
        where: '$columnFinalGoodId = ?',
        whereArgs: [pendingGood.goodsId]
    );
    final goodBOMEntries = goodsBOMs.map((map) => GoodBOMEntry.fromMap(map)).toList();
    for (final entry in goodBOMEntries) {
        final consumedQty = entry.quantityNeeded * pendingGood.quantityInProduction;
        final goodMaps = await txn.query(tableGoods, where: '$columnGoodsId = ?', whereArgs: [entry.componentGoodId]);
        final componentGood = Good.fromMap(goodMaps.first);

        await txn.update(
            tableGoods,
            {columnGoodsRemainingQuantity: componentGood.quantity + consumedQty},
            where: '$columnGoodsId = ?',
            whereArgs: [entry.componentGoodId]
        );
    }

    await txn.delete(
      tablePendingGoods,
      where: '$columnPendingId = ?',
      whereArgs: [pendingGood.pendingId],
    );
  });
}

}
