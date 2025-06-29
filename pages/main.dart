// lib/main.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.18.1
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'add_good_page.dart';
import 'add_raw_material_page.dart';
import 'add_pending_good_page.dart';
import 'good_detail_page.dart';
import 'raw_material_detail_page.dart';
import 'pending_good_detail_page.dart';
import "edit_good_page.dart";
import "edit_raw_material_page.dart";
import 'package:goods_inventory_app/models/models.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized for database path and async operations.
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database; 
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Default color scheme to be used if dynamic color is not available.
  static final _defaultColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder provides the device's color scheme.
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: '库存管理',
          theme: ThemeData(
            // Use the dynamic color scheme if available, otherwise use the default.
            colorScheme: lightDynamic ?? _defaultColorScheme,
            useMaterial3: true,
            listTileTheme: ListTileThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
          // You can also configure a dark theme similarly:
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? _defaultColorScheme.copyWith(brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DatabaseHelper.instance;

  List<Good> _finalGoods = [];
  List<Good> _componentGoods = [];
  List<RawMaterials> _rawMaterials = [];
  List<PendingGood> _pendingGoods = [];
  List<PendingGood> _inStoreGoods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() { _isLoading = true; });
    final allGoods = await dbHelper.getAllGoods();
    final rawMaterialsData = await dbHelper.getAllRawMaterials();
    final pendingGoodsData = await dbHelper.getAllPendingGoods();
    final inStoreData = await dbHelper.getAllInStoreGoods();

    if (mounted) {
      setState(() {
        _finalGoods = allGoods.where((g) => !g.isComponent).toList();
        _componentGoods = allGoods.where((g) => g.isComponent).toList();

        _inStoreGoods = inStoreData;
        _rawMaterials = rawMaterialsData;
        _pendingGoods = pendingGoodsData;
        _isLoading = false;
      });
    }
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: const Text('新生产'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPendingGoodPage()));
                  _refreshData();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('增加商品'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddGoodPage()));
                  _refreshData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('增加原料'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRawMaterialPage()));
                  _refreshData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a confirmation dialog before deleting an item.
  Future<bool> _showDeleteConfirmationDialog({String title = '你确定吗?', String content = '该操作不能撤销.'}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showInStoreActionDialog({required PendingGood completedGood, required bool isStocking}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final action = isStocking ? '入库' : '出库';
    final goodName = completedGood.goodName ?? '物品';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$action Quantity for $goodName'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('剩余待出库: ${completedGood.quantityInProduction}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '$action 数量',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入数量';
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return '数量不能为负';
                    if (qty > completedGood.quantityInProduction) return '$action 不能超过剩余数量';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text(action),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final quantity = int.parse(controller.text);
                  try {
                    if (isStocking) {
                      await dbHelper.stockInStoreGood(completedGood, quantity);
                    } else {
                      await dbHelper.exportInStoreGood(completedGood, quantity);
                    }
                    Navigator.of(context).pop();
                    _refreshData();
                  } catch (e) {
                     if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

// --- UI Builder Methods ---
  Widget _buildInStoreList() {
    if (_inStoreGoods.isEmpty) {
      return const Center(child: Text('目前没有待入库商品.', textAlign: TextAlign.center));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _inStoreGoods.length,
      itemBuilder: (context, index) {
        final completedGood = _inStoreGoods[index];
        final formattedDate = DateFormat.yMd().add_jm().format(completedGood.startDate);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.check_box, color: Colors.blueGrey),
            title: Text(completedGood.goodName ?? '未知商品', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${completedGood.quantityInProduction} | 完成于: $formattedDate'),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PendingGoodDetailPage(pendingGood: completedGood)),
              );
              if (result == true) { 
                _refreshData(); 
              }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.inventory_outlined, color: Colors.green),
                  tooltip: '入库',
                  onPressed: () => _showInStoreActionDialog(completedGood: completedGood, isStocking: true),
                ),
                IconButton(
                  icon: Icon(Icons.local_shipping_outlined, color: Theme.of(context).colorScheme.primary),
                  tooltip: '出库',
                  onPressed: () => _showInStoreActionDialog(completedGood: completedGood, isStocking: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinalGoodsList() {
    if (_finalGoods.isEmpty) {
        return const Center(child: Text('未找到商品.\n按“ + ”号来添加.', textAlign: TextAlign.center));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _finalGoods.length,
      itemBuilder: (context, index) {
        final good = _finalGoods[index];
        return Card(
          child: ListTile(
            title: Text(good.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${good.quantity}'),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => GoodDetailPage(good: good)));
              if(result == true) { _refreshData(); }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary), // Changed icon
                  tooltip: '编辑商品', // Changed tooltip
                  onPressed: () async { // Changed action
                    // Navigate to the new EditGoodPage and refresh when done
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditGoodPage(good: good)),
                    );
                    _refreshData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '删除',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog()) {
                      await dbHelper.deleteGood(good.goodsId!);
                      _refreshData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComponentGoodsList() {
    if (_componentGoods.isEmpty) { return const Center(child: Text('未找到半成品.\n按“ + ”号来添加.', textAlign: TextAlign.center)); }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _componentGoods.length,
      itemBuilder: (context, index) {
        final good = _componentGoods[index];
        return Card(
          child: ListTile(
            title: Text(good.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${good.quantity}'),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => GoodDetailPage(good: good)));
              if(result == true) { _refreshData(); }
            },            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                  tooltip: '编辑半成品',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => EditGoodPage(good: good)));
                    _refreshData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '删除',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog()) {
                      await dbHelper.deleteGood(good.goodsId!);
                      _refreshData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRawMaterialsList() {
    if (_rawMaterials.isEmpty) {
      return const Center(child: Text('未找到原料.\n按“ + ”号来添加.', textAlign: TextAlign.center));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _rawMaterials.length,
      itemBuilder: (context, index) {
        final material = _rawMaterials[index];
        return Card(
          //margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${material.quality}'),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => RawMaterialDetailPage(material: material)));
              if(result == true) { _refreshData(); }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary), // Changed icon
                  tooltip: '编辑原材料', // Changed tooltip
                  onPressed: () async { // Changed action
                    // Navigate to the new EditRawMaterialPage and refresh when done
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditRawMaterialPage(material: material)),
                    );
                    _refreshData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '删除',
                  onPressed: () async {
                     if (await _showDeleteConfirmationDialog()) {
                      await dbHelper.deleteRawMaterial(material.materialID!);
                      _refreshData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingGoodsList() {
    if (_pendingGoods.isEmpty) { return const Center(child: Text('目前没有生产中商品.', textAlign: TextAlign.center)); }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pendingGoods.length,
      itemBuilder: (context, index) {
        final pending = _pendingGoods[index];
        final formattedDate = DateFormat.yMd().add_jm().format(pending.startDate);
        return Card(
          child: ListTile(
            title: Text(pending.goodName ?? '未知商品', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${pending.quantityInProduction} | 开始于: $formattedDate'),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PendingGoodDetailPage(pendingGood: pending)),
              );
              if (result == true) { 
                _refreshData(); 
              }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: '完成生产',
                  onPressed: () async {
                    if(await _showDeleteConfirmationDialog(title: '生产已完成?', content: '这将会把 ${pending.quantityInProduction} 个 "${pending.goodName}" 加入到待入库清单中.')) {
                        await dbHelper.completeProduction(pending);
                        _refreshData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  tooltip: '取消生产',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog(title: '取消生产?', content: '这将会返还原材料到原材料库存中.')) {
                      await dbHelper.cancelProduction(pending);
                      _refreshData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('库存面板'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            //isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.build_circle_outlined), text: '生产中'),
              Tab(icon: Icon(Icons.storefront_outlined), text: '待入库'),
              Tab(icon: Icon(Icons.category_outlined), text: '商品'),
              Tab(icon: Icon(Icons.inventory_2), text: '半成品'), 
              Tab(icon: Icon(Icons.layers), text: '原料'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPendingGoodsList(),
                  _buildInStoreList(),
                  _buildFinalGoodsList(), // New List View
                  _buildComponentGoodsList(), // Old list now shows only components
                  _buildRawMaterialsList(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddOptions(context),
          tooltip: '增加...',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
