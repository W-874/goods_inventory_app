import 'databaseHelper.dart';
import 'package:meta/meta.dart';


class Goods{
  int? goodsID = 0;
  String name = "default";
  int quality = 0;
  double price = 0;
  String? description;

  

  Goods({this.goodsID, required this.name, required this.quality, required this.price, this.description});

  factory Goods.fromMap(Map<String, dynamic> map) {
    return Goods(
      goodsID: map[columnGoodsId] as int,
      name: map[columnName] as String,
      quality: map[columnGoodsRemainingQuantity] as int,
      price: (map[columnPrice] as num).toDouble(),
      description: map[columnDescription] as String?,
    );
  }

  Map<String, dynamic> toMap({bool forInsertAndAutoincrement = false}) {
    final map = <String, dynamic>{
      columnName: name,
      columnGoodsRemainingQuantity: quality,
      columnPrice: price,
      columnDescription: description,
    };
    // If ID is not auto-incrementing OR it's an update OR ID is manually set for insert
    if (!forInsertAndAutoincrement || goodsID != 0) { // Assuming 0 is not a valid ID for autoincrement indication
        map[columnGoodsId] = goodsID;
    }
    return map;
  }

  Goods copyWith({
    int? goodsID,
    String? name,
    int? quality,
    double? price,
    String? description,
  }) {
    return Goods(
      goodsID : goodsID ?? this.goodsID,
      name : name ?? this.name, 
      quality : quality ?? this.quality,
      price : price ?? this.price,
      description : description ?? this.description);
  }

  @override
  String toString() {
    return 'Goods(goodsID: $goodsID, name: $name, quality: $quality, price: $price, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Goods &&
        other.goodsID == goodsID &&
        other.name == name &&
        other.quality == quality &&
        other.price == price &&
        other.description == description;
  }

  @override
  int get hashCode {
    return goodsID.hashCode ^
        name.hashCode ^
        quality.hashCode ^
        price.hashCode ^
        description.hashCode;
  }
}

class RawMaterials{
  int? materialID = 0;
  String name = "default";
  int quality = 0;
  double price = 0;
  String? description = "null";

  RawMaterials({this.materialID, required this.name, required this.quality, required this.price, this.description});

  factory RawMaterials.fromMap(Map<String, dynamic> map) {
    return RawMaterials(
      materialID: map[columnRawMaterialId] as int,
      name: map[columnName] as String,
      quality: map[columnRawMaterialRemainingQuantity] as int,
      price: map[columnPrice] as double,
      description: map[columnDescription] as String?,
      );
  }

  Map<String, dynamic> toMap({bool forInsertAndAutoincrement = false}) {
     final map = <String, dynamic>{
      columnName: name,
      columnRawMaterialRemainingQuantity: quality,
      columnPrice: price,
      columnDescription :description,
    };
    if (!forInsertAndAutoincrement || materialID != 0) {
        map[columnRawMaterialId] = materialID;
    }
    return map;
  }

  RawMaterials copyWith({
    int? materialID,
    String? name,
    int? quality,
    double? price,
    String? description,
  }) {
    return RawMaterials(
      materialID : materialID ?? this.materialID,
      name : name ?? this.name, 
      quality : quality ?? this.quality,
      price : price ?? this.price,
      description : description ?? this.description);
  }

  @override
  String toString() {
    return 'RawMaterials(materialID: $materialID, name: $name, quality: $quality, price: $price, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RawMaterials &&
        other.materialID == materialID &&
        other.name == name &&
        other.quality == quality &&
        other.price == price &&
        other.description == description;
  }

  @override
  int get hashCode {
    return materialID.hashCode ^
        name.hashCode ^
        quality.hashCode ^
        price.hashCode ^
        description.hashCode;
  }


}

@immutable
class BillOfMaterialEntry {
  final int goodsId;
  final int rawMaterialId;
  final int quantityNeeded;

  const BillOfMaterialEntry({
    required this.goodsId,
    required this.rawMaterialId,
    required this.quantityNeeded,
  });

  factory BillOfMaterialEntry.fromMap(Map<String, dynamic> map) {
    return BillOfMaterialEntry(
      goodsId: map[columnGoodsId] as int,
      rawMaterialId: map[columnRawMaterialId] as int,
      quantityNeeded: map[columnQuantityNeeded] as int,
    );
  }

  Map<String, dynamic> toMap() {
    // This table has a composite PK, no autoincrement for the entry itself
    return {
      columnGoodsId: goodsId,
      columnRawMaterialId: rawMaterialId,
      columnQuantityNeeded: quantityNeeded,
    };
  }

  BillOfMaterialEntry copyWith({
    int? goodsId,
    int? rawMaterialId,
    int? quantityNeeded,
  }) {
    return BillOfMaterialEntry(
      goodsId: goodsId ?? this.goodsId,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
    );
  }

  @override
  String toString() {
    return 'BillOfMaterialEntry(goodsId: $goodsId, rawMaterialId: $rawMaterialId, quantityNeeded: $quantityNeeded)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillOfMaterialEntry &&
        other.goodsId == goodsId &&
        other.rawMaterialId == rawMaterialId &&
        other.quantityNeeded == quantityNeeded;
  }

  @override
  int get hashCode {
    return goodsId.hashCode ^
        rawMaterialId.hashCode ^
        quantityNeeded.hashCode;
  }
}

@immutable
class PendingGood {
  final int? pendingId; // Nullable for creation, non-null from DB
  final int goodsId;
  final int quantityInProduction;
  final DateTime startDate;
  final bool isUnderConstruction; // New status field

  // This will be populated by a JOIN query, not stored in the table
  final String? goodName;

  const PendingGood({
    this.pendingId,
    required this.goodsId,
    required this.quantityInProduction,
    required this.startDate,
    required this.isUnderConstruction,
    this.goodName, // For display purposes
  });

  factory PendingGood.fromMap(Map<String, dynamic> map) {
    return PendingGood(
      pendingId: map[columnPendingId] as int,
      goodsId: map[columnGoodsId] as int,
      quantityInProduction: map[columnQuantityInProduction] as int,
      startDate: DateTime.parse(map[columnStartDate] as String),
      // SQLite stores booleans as integers (0 or 1)
      isUnderConstruction: map[columnStatus] == 1,
      // The goodName will be present if the query used a JOIN
      goodName: map[columnName] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      columnGoodsId: goodsId,
      columnQuantityInProduction: quantityInProduction,
      columnStartDate: startDate.toIso8601String(),
      // Convert boolean to integer for SQLite
      columnStatus: isUnderConstruction ? 1 : 0,
    };
    // Only include pendingId if it's not null (for updates)
    if (pendingId != null) {
      map[columnPendingId] = pendingId;
    }
    return map;
  }

  PendingGood copyWith({
    int? pendingId,
    int? goodsId,
    int? quantityInProduction,
    DateTime? startDate,
    bool? isUnderConstruction,
    String? goodName,
  }) {
    return PendingGood(
      pendingId: pendingId ?? this.pendingId,
      goodsId: goodsId ?? this.goodsId,
      quantityInProduction: quantityInProduction ?? this.quantityInProduction,
      startDate: startDate ?? this.startDate,
      isUnderConstruction: isUnderConstruction ?? this.isUnderConstruction,
      goodName: goodName ?? this.goodName,
    );
  }
}
