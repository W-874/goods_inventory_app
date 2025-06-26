import 'package:meta/meta.dart';
import '../db_constants.dart';


class Good{
  final int? goodsId;
  final String name;
  final int quantity;
  final double? price;
  final String? description;
  final bool isComponent;


  const Good({
    required this.goodsId,
    required this.name,
    required this.quantity,
    this.price,
    this.description,
    required this.isComponent,
  });

  factory Good.fromMap(Map<String, dynamic> map) {
    final priceFromDb = map[columnPrice];

    return Good(
      goodsId: map[columnGoodsId] as int,
      name: map[columnName] as String,
      quantity: map[columnGoodsRemainingQuantity] as int,
      price: priceFromDb != null ? (priceFromDb as num).toDouble() : null,
      description: map[columnDescription] as String?,
      isComponent: (map[columnIsComponent] as int) == 1,
    );
  }

  Map<String, dynamic> toMap({bool forInsertAndAutoincrement = false}) {
    final map = <String, dynamic>{
      columnName: name,
      columnGoodsRemainingQuantity: quantity,
      columnPrice: price,
      columnDescription: description,
      columnIsComponent: isComponent ? 1 : 0,
    };
    // If ID is not auto-incrementing OR it's an update OR ID is manually set for insert
    if (!forInsertAndAutoincrement || goodsId != 0) { // Assuming 0 is not a valid ID for autoincrement indication
      map[columnGoodsId] = goodsId;
    }
    return map;
  }

  Good copyWith({
    int? goodsID,
    String? name,
    int? quality,
    double? price,
    String? description,
    bool? isComponent,
  }) {
    return Good(
      goodsId : goodsID ?? this.goodsId,
      name : name ?? this.name,
      quantity : quality ?? this.quantity,
      price : price ?? this.price,
      description : description ?? this.description,
      isComponent: isComponent ?? this.isComponent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Good &&
        other.goodsId == goodsId &&
        other.name == name &&
        other.quantity == quantity &&
        other.price == price &&
        other.description == description &&
        other.isComponent == isComponent;
  }

  @override
  int get hashCode {
    return goodsId.hashCode ^
    name.hashCode ^
    quantity.hashCode ^
    price.hashCode ^
    description.hashCode ^
    isComponent.hashCode;
  }
}