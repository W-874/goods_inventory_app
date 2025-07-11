import 'package:meta/meta.dart';
import 'db_constants.dart';
import 'models/models.dart';

class RawMaterials{
  int? materialID = 0;
  String name = "default";
  int quality = 0;
  double? price = 0;
  String? description = "null";

  RawMaterials({this.materialID, required this.name, required this.quality, this.price, this.description});

  factory RawMaterials.fromMap(Map<String, dynamic> map) {
    return RawMaterials(
      materialID: map[columnRawMaterialId] as int,
      name: map[columnName] as String,
      quality: map[columnRawMaterialRemainingQuantity] as int,
      price: map[columnPrice] != null ? (map[columnPrice] as num).toDouble() : null,
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
  final String? rawMaterialName;
  final String? goodName; // For raw_material_detail_page
 // Added field for display

  const BillOfMaterialEntry({
    required this.goodsId,
    required this.rawMaterialId,
    required this.quantityNeeded,
    this.rawMaterialName,
    this.goodName,
  });

  factory BillOfMaterialEntry.fromMap(Map<String, dynamic> map) {
    return BillOfMaterialEntry(
      goodsId: map[columnGoodsId] as int,
      rawMaterialId: map[columnRawMaterialId] as int,
      quantityNeeded: map[columnQuantityNeeded] as int,
      // The names will be present if the query used a JOIN
      rawMaterialName: map[columnName] as String?, // Can map to either good or material name
      goodName: map[columnName] as String?, // Same as above, context depends on query
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
    String? rawMaterialName,
    String? goodName,
  }) {
    return BillOfMaterialEntry(
      goodsId: goodsId ?? this.goodsId,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      rawMaterialName: rawMaterialName ?? this.rawMaterialName,
      goodName: goodName ?? this.goodName,
    );
  }

  @override
  String toString() {
    return 'BillOfMaterialEntry(goodsId: $goodsId, rawMaterialId: $rawMaterialId, quantityNeeded: $quantityNeeded, rawMaterialName: $rawMaterialName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillOfMaterialEntry &&
        other.goodsId == goodsId &&
        other.rawMaterialId == rawMaterialId &&
        other.quantityNeeded == quantityNeeded &&
        other.rawMaterialName == rawMaterialName &&
        other.goodName == goodName;
  }

  @override
  int get hashCode {
    return goodsId.hashCode ^
        rawMaterialId.hashCode ^
        quantityNeeded.hashCode ^
        rawMaterialName.hashCode ^
        goodName.hashCode;
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
