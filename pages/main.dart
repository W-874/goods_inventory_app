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
      title: 'Inventory Manager',
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
                title: const Text('Start New Production'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPendingGoodPage()));
                  _refreshData();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Add Good'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddGoodPage()));
                  _refreshData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Add Raw Material'),
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
          title: Text('Update Quantity for $itemName'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Quantity: $currentQuantity'),
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
                      return 'Please enter a value';
                    }
                    final change = int.tryParse(value);
                    if (change == null) {
                      return 'Please enter a valid number';
                    }
                    if (currentQuantity + change < 0) {
                      return 'Stock cannot go below zero';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
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
  Future<bool> _showDeleteConfirmationDialog({String title = 'Are you sure?', String content = 'This action cannot be undone.'}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // --- UI Builder Methods ---

  Widget _buildGoodsList() {
    if (_goods.isEmpty) {
      return const Center(child: Text('No goods found.\nPress + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
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
            subtitle: Text('Qty: ${good.quality} | Price: \$${good.price.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Update Quantity',
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
                  tooltip: 'Delete',
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
      return const Center(child: Text('No raw materials found.\nPress + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
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
            subtitle: Text('Qty: ${material.quality}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Update Quantity',
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
                  tooltip: 'Delete',
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
      return const Center(child: Text('No goods are currently in production.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
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
            title: Text(pending.goodName ?? 'Unknown Good', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Qty: ${pending.quantityInProduction} | Started: $formattedDate'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Complete Production',
                  onPressed: () async {
                    if(await _showDeleteConfirmationDialog(title: 'Complete Production?', content: 'This will add ${pending.quantityInProduction} to "${pending.goodName}" stock.')) {
                        await dbHelper.completeProduction(pending);
                        _refreshData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  tooltip: 'Cancel Production',
                  onPressed: () async {
                    if (await _showDeleteConfirmationDialog(title: 'Cancel Production?', content: 'This will return consumed raw materials to stock.')) {
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
          title: const Text('Inventory Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.build_circle_outlined), text: 'In Production'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Goods'),
              Tab(icon: Icon(Icons.layers), text: 'Raw Materials'),
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
          tooltip: 'Add...',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
