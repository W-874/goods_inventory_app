// --- Table Names ---
const String tableGoods = 'goods';
const String tableRawMaterials = 'rawmaterials';
const String tableBillOfMaterials = 'billofmaterials';
const String tablePendingGoods = 'pending_goods';

// --- Goods Table Columns ---
const String columnGoodsId = 'goods_id';
const String columnName = 'name'; // Common column, but used with table prefix in queries
const String columnGoodsRemainingQuantity = 'remaining_quantity';
const String columnPrice = 'price';
const String columnDescription = 'description';

// --- RawMaterials Table Columns ---
const String columnRawMaterialId = 'raw_material_id';
// columnName is already defined
const String columnRawMaterialRemainingQuantity = 'remaining_quantity';
// columnPrice is already defined
// columnDescription is already defined

// --- BillOfMaterials Table Columns ---
// columnGoodsId is already defined (used for FK)
// columnRawMaterialId is already defined (used for FK)
const String columnQuantityNeeded = 'quantity_needed';

// --- PendingGoods Table Columns ---
const String columnPendingId = 'pending_id';
// columnGoodsId is already defined
const String columnQuantityInProduction = 'quantity_in_production';
const String columnStartDate = 'start_date';
const String columnStatus = 'status';
