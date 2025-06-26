// lib/models/good_bom_entry.dart
import 'package:meta/meta.dart';
import '../db_constants.dart';

@immutable
class GoodBOMEntry {
  final int finalGoodId;
  final int componentGoodId;
  final int quantityNeeded;
  final String? componentGoodName;

  const GoodBOMEntry({
    required this.finalGoodId,
    required this.componentGoodId,
    required this.quantityNeeded,
    this.componentGoodName,
  });

  factory GoodBOMEntry.fromMap(Map<String, dynamic> map) {
    return GoodBOMEntry(
      finalGoodId: map[columnFinalGoodId] as int,
      componentGoodId: map[columnComponentGoodId] as int,
      quantityNeeded: map[columnQuantityNeeded] as int,
      componentGoodName: map[columnName] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      columnFinalGoodId: finalGoodId,
      columnComponentGoodId: componentGoodId,
      columnQuantityNeeded: quantityNeeded,
    };
  }
}