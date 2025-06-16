// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.18.1
import '../lib/databaseHelper.dart';
import '../lib/dataClass.dart';
import 'add_good_page.dart';
import 'add_raw_material_page.dart';
import 'add_pending_good_page.dart';

void main() {
  // Ensure that plugin services are initialized for database path.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '库存管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      home: const HomePage(),
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

  List<Goods> _goods = [];
  List<RawMaterials> _rawMaterials = [];
  List<PendingGood> _pendingGoods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    final goodsData = await dbHelper.getAllGoods();
    final rawMaterialsData = await dbHelper.getAllRawMaterials();
    final pendingGoodsData = await dbHelper.getAllPendingGoods();
    // Ensure the widget is still mounted before setting state.
    if (mounted) {
      setState(() {
        _goods = goodsData;
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

  /// Shows a dialog to update the quantity of an item.
  Future<void> _showUpdateQuantityDialog({
    required String itemName,
    required int currentQuantity,
    required Future<void> Function(int quantityChange) onSave,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('更新 $itemName 的数量'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前数量: $currentQuantity'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Change (+/-)',
                    hintText: 'e.g., 10 or -5',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入';
                    }
                    final change = int.tryParse(value);
                    if (change == null) {
                      return '请输入数字';
                    }
                    if (currentQuantity + change < 0) {
                      return '库存不能为负数';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('保存'),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final change = int.tryParse(controller.text) ?? 0;
                  await onSave(change);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
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

  // --- UI Builder Methods ---

  Widget _buildGoodsList() {
    if (_goods.isEmpty) {
      return const Center(child: Text('未找到商品.\n按“ + ”号来添加.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _goods.length,
      itemBuilder: (context, index) {
        final good = _goods[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(good.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${good.quality} | 价格: \$${good.price.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                  tooltip: '更新数量',
                  onPressed: () {
                    _showUpdateQuantityDialog(
                      itemName: good.name,
                      currentQuantity: good.quality,
                      onSave: (change) async {
                        final updatedGood = good.copyWith(
                          quality: good.quality + change,
                        );
                        await dbHelper.updateGood(updatedGood);
                        _refreshData();
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '删除',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog()) {
                      await dbHelper.deleteGood(good.goodsID!);
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
      return const Center(child: Text('未找到原料.\n按“ + ”号来添加.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _rawMaterials.length,
      itemBuilder: (context, index) {
        final material = _rawMaterials[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${material.quality}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                  tooltip: '更新数量',
                  onPressed: () {
                     _showUpdateQuantityDialog(
                      itemName: material.name,
                      currentQuantity: material.quality,
                      onSave: (change) async {
                        final updatedMaterial = material.copyWith(
                          quality: material.quality + change,
                        );
                        await dbHelper.updateRawMaterial(updatedMaterial);
                        _refreshData();
                      },
                    );
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
    if (_pendingGoods.isEmpty) {
      return const Center(child: Text('目前没有正在进行的生产.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pendingGoods.length,
      itemBuilder: (context, index) {
        final pending = _pendingGoods[index];
        final formattedDate = DateFormat.yMd().add_jm().format(pending.startDate);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            title: Text(pending.goodName ?? '未知商品', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('数量: ${pending.quantityInProduction} | 开始于: $formattedDate'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: '完成生产',
                  onPressed: () async {
                    if(await _showDeleteConfirmationDialog(title: '完成该生产？', content: 'This will add ${pending.quantityInProduction} to "${pending.goodName}" stock.')) {
                        await dbHelper.completeProduction(pending);
                        _refreshData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  tooltip: '取消生产',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog(title: '取消该生产？', content: 'This will return consumed raw materials to stock.')) {
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('库存面板'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.build_circle_outlined), text: '生产中'),
              Tab(icon: Icon(Icons.inventory_2), text: '商品'),
              Tab(icon: Icon(Icons.layers), text: '原料'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPendingGoodsList(),
                  _buildGoodsList(),
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
