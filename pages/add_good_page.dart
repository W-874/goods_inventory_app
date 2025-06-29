// lib/pages/add_good_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'package:goods_inventory_app/db_constants.dart';
import 'package:goods_inventory_app/models/models.dart';
import 'package:sqflite/sqflite.dart';

class AddGoodPage extends StatefulWidget {
  const AddGoodPage({super.key});

  @override
  State<AddGoodPage> createState() => _AddGoodPageState();
}

class _AddGoodPageState extends State<AddGoodPage> {
  // A global key that uniquely identifies the Form widget and allows validation.
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  // Controllers to manage the text being edited in the TextFormFields.
  final _goodsIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isComponent = false;

  // State for managing the Bill of Materials selection
  List<RawMaterials> _allRawMaterials = [];
  Map<int, RawMaterials> _selectedMaterialsMap = {}; // Key: rawMaterialId, Value: RawMaterial
  Map<int, TextEditingController> _materialQuantityControllers = {}; // Key: rawMaterialId
  List<Good> _allGoods = [];
  Map<int, Good> _selectedComponentGoods = {};
  Map<int, TextEditingController> _goodQuantityControllers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllRawMaterials();
    _loadAllGoods();
  }

  Future<void> _loadAllGoods() async {
    final goods = await _dbHelper.getAllGoods();
    if(mounted) setState(() => _allGoods = goods);
  }

  Future<void> _loadAllRawMaterials() async {
    final materials = await _dbHelper.getAllRawMaterials();
    if(mounted) {
      setState(() {
        _allRawMaterials = materials;
      });
    }
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _goodsIdController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (var controller in _materialQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _showMaterialSelectionDialog() async {
    Map<int, RawMaterials> tempSelected = Map.from(_selectedMaterialsMap);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择需要的原材料'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allRawMaterials.isEmpty
                    ? const Text('未找到原材料. 请先添加原材料. ')
                    : ListView.builder(
                        itemCount: _allRawMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _allRawMaterials[index];
                          return CheckboxListTile(
                            title: Text(material.name),
                            subtitle: Text('ID: ${material.materialID}'),
                            value: tempSelected.containsKey(material.materialID),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected[material.materialID!] = material;
                                } else {
                                  tempSelected.remove(material.materialID);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMaterialsMap = tempSelected;
                      final oldKeys = _materialQuantityControllers.keys.toSet();
                      final newKeys = _selectedMaterialsMap.keys.toSet();
                      
                      oldKeys.difference(newKeys).forEach((key) {
                        _materialQuantityControllers[key]?.dispose();
                        _materialQuantityControllers.remove(key);
                      });

                      for (var key in newKeys) {
                        if (!_materialQuantityControllers.containsKey(key)) {
                          _materialQuantityControllers[key] = TextEditingController();
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showComponentGoodSelectionDialog() async {
    Map<int, Good> tempSelected = Map.from(_selectedComponentGoods);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择需要的半成品'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allGoods.isEmpty
                    ? const Text('未找到商品. 请先添加商品. ')
                    : ListView.builder(
                        itemCount: _allGoods.length,
                        itemBuilder: (context, index) {
                          final good = _allGoods[index];
                          return CheckboxListTile(
                            title: Text(good.name),
                            subtitle: Text('ID: ${good.goodsId}'),
                            value: tempSelected.containsKey(good.goodsId),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected[good.goodsId!] = good;
                                } else {
                                  tempSelected.remove(good.goodsId);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedComponentGoods = tempSelected;
                      final oldKeys = _goodQuantityControllers.keys.toSet();
                      final newKeys = _selectedComponentGoods.keys.toSet();
                      
                      oldKeys.difference(newKeys).forEach((key) {
                        _goodQuantityControllers[key]?.dispose();
                        _goodQuantityControllers.remove(key);
                      });

                      for (var key in newKeys) {
                        if (!_goodQuantityControllers.containsKey(key)) {
                          _goodQuantityControllers[key] = TextEditingController();
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _saveAll() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
        _showSnackBar('Please fix the errors in the form.', isError: true);
        return;
    }

    for (var controller in {..._materialQuantityControllers, ..._goodQuantityControllers}.values) {
        if(controller.text.isEmpty || int.tryParse(controller.text) == null) {
            _showSnackBar('请为所有选择的原材料输入正确的数值.', isError: true);
            return;
        }
    }

    setState(() { _isLoading = true; });

    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        final goodsIdFromForm = int.tryParse(_goodsIdController.text);
        
        final newGood = Good(
          goodsId: goodsIdFromForm ?? 0,
          name: _nameController.text,
          quantity: int.parse(_quantityController.text),
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          isComponent: _isComponent,
        );

        int newGoodsId;
        if (goodsIdFromForm != null) {
          await txn.insert(tableGoods, newGood.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
          newGoodsId = goodsIdFromForm;
        } else {
          newGoodsId = await txn.insert(tableGoods, newGood.toMap(forInsertAndAutoincrement: true));
        }

        if (newGoodsId <= 0) {
            throw Exception("Failed to create the new good.");
        }

        for (final materialId in _selectedMaterialsMap.keys) {
          final quantity = int.parse(_materialQuantityControllers[materialId]!.text);
          final bomEntry = BillOfMaterialEntry(
            goodsId: newGoodsId,
            rawMaterialId: materialId,
            quantityNeeded: quantity,
          );
          await txn.insert(tableBillOfMaterials, bomEntry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final goodId in _selectedComponentGoods.keys) {
            final quantity = int.parse(_goodQuantityControllers[goodId]!.text);
            final goodBomEntry = GoodBOMEntry(
                finalGoodId: newGoodsId,
                componentGoodId: goodId,
                quantityNeeded: quantity,
            );
            await txn.insert(tableGoodsBOM, goodBomEntry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      _showSnackBar('商品保存成功!');
      if(mounted) Navigator.pop(context);

    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed') || e.toString().contains('ConflictAlgorithm.fail')) {
        _showSnackBar('Error: A good with this ID already exists.', isError: true);
      } else {
        _showSnackBar('An error occurred: $e', isError: true);
      }
    } finally {
      if(mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelectedMaterials = _selectedMaterialsMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('增加新商品'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                //Text('Good Details', style: Theme.of(context).textTheme.titleLarge),
                //const SizedBox(height: 16),
                TextFormField(
                  controller: _goodsIdController,
                  decoration: const InputDecoration(labelText: '商品ID (可选)', border: OutlineInputBorder(), hintText: '留空来自动生成'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.isNotEmpty && int.tryParse(v) == null ? 'Must be a valid number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '商品名称', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.isEmpty ? '请输入商品名称' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: '当前数量', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? '请输入有效数字' : null,
                ),
                // const SizedBox(height: 16),
                // TextFormField(
                //   controller: _priceController,
                //   decoration: const InputDecoration(labelText: '商品价格', border: OutlineInputBorder(), prefixText: '\$'),
                //   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                //   validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? '请输入有效价格' : null,
                // ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '商品描述 (可选)', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                // --- NEW SWITCH FOR isComponent ---
                SwitchListTile(
                  title: const Text('半成品'),
                  subtitle: const Text('Is this a semi-finished product used to make other goods?'),
                  value: _isComponent,
                  onChanged: (bool value) {
                    setState(() {
                      _isComponent = value;
                    });
                  },
                ),
                const Divider(height: 40, thickness: 1),

                Text('所需材料', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                
                Text('所需原材料', style: Theme.of(context).textTheme.titleMedium),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text('选择原材料...'),
                  onPressed: _showMaterialSelectionDialog,
                ),
                
                if (sortedSelectedMaterials.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedSelectedMaterials.length,
                    itemBuilder: (context, index) {
                      final material = sortedSelectedMaterials[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(material.name, style: const TextStyle(fontSize: 16))),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _materialQuantityControllers[material.materialID],
                                decoration: const InputDecoration(labelText: 'Qty Needed', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? 'Req.' : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),

                Text('所需半成品', style: Theme.of(context).textTheme.titleMedium),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text('选择半成品...'),
                  onPressed: _showComponentGoodSelectionDialog,
                ),

                if (_selectedComponentGoods.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedComponentGoods.length,
                    itemBuilder: (context, index) {
                      final good = _selectedComponentGoods.values.toList()..sort((a, b) => a.name.compareTo(b.name));
                      final componentGood = good[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(componentGood.name, style: const TextStyle(fontSize: 16))),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _goodQuantityControllers[componentGood.goodsId],
                                decoration: const InputDecoration(labelText: 'Qty Needed', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? 'Req.' : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAll,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('保存商品'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
