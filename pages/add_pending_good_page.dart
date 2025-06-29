// lib/pages/add_pending_good_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'package:goods_inventory_app/models/models.dart';

class AddPendingGoodPage extends StatefulWidget {
  const AddPendingGoodPage({super.key});

  @override
  State<AddPendingGoodPage> createState() => _AddPendingGoodPageState();
}

class _AddPendingGoodPageState extends State<AddPendingGoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  Good? _selectedGood;
  List<Good> _allGoods = [];
  final _quantityController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllGoods();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadAllGoods() async {
    final goods = await _dbHelper.getAllGoods();
    if (mounted) {
      setState(() {
        _allGoods = goods;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  Future<void> _startProduction() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isLoading = true; });

    try {
      await _dbHelper.startProduction(
        _selectedGood!.goodsId!,
        int.parse(_quantityController.text),
      );
      _showSnackBar('生产成功开始!');
      if (mounted) {
        Navigator.pop(context); // Go back to the main page after success
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开始新生产'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Good>(
                  value: _selectedGood,
                  decoration: const InputDecoration(
                    labelText: '选择要生产的商品',
                    border: OutlineInputBorder(),
                  ),
                  items: _allGoods.map((good) {
                    return DropdownMenuItem<Good>(
                      value: good,
                      child: Text(good.name),
                    );
                  }).toList(),
                  onChanged: (Good? newValue) {
                    setState(() {
                      _selectedGood = newValue;
                    });
                  },
                  validator: (value) => value == null ? '请选择一个商品' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: '生产数量',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入数量';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return '生产数量不能为负';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _startProduction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('开始生产'),
                ),
                const SizedBox(height: 24),
                if (_selectedGood != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('所需材料:', style: Theme.of(context).textTheme.titleMedium),
                          const Divider(),
                          // FutureBuilder for Raw Materials
                          FutureBuilder<List<BillOfMaterialEntry>>(
                            future: _dbHelper.getRawMaterialBOMForGood(_selectedGood!.goodsId!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const SizedBox.shrink(); // Don't show anything if there are no raw materials
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('原材料:', style: Theme.of(context).textTheme.titleSmall),
                                  const SizedBox(height: 4),
                                  for (var item in snapshot.data!)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                      child: Text('- ${item.rawMaterialName ?? '未知'} (数量: ${item.quantityNeeded})'),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // FutureBuilder for Component Goods
                          FutureBuilder<List<GoodBOMEntry>>(
                            future: _dbHelper.getGoodsBOMForGood(_selectedGood!.goodsId!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const SizedBox.shrink(); // Don't show anything if there are no component goods
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('半成品:', style: Theme.of(context).textTheme.titleSmall),
                                  const SizedBox(height: 4),
                                  for (var item in snapshot.data!)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                      child: Text('- ${item.componentGoodName ?? '未知'} (数量: ${item.quantityNeeded})'),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
