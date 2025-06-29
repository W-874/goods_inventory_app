// lib/pages/edit_good_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'package:goods_inventory_app/db_constants.dart';
import 'package:goods_inventory_app/models/models.dart';

class EditGoodPage extends StatefulWidget {
  final Good good;

  const EditGoodPage({super.key, required this.good});

  @override
  State<EditGoodPage> createState() => _EditGoodPageState();
}

class _EditGoodPageState extends State<EditGoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  // Controllers to manage the text being edited
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  
  late bool _isComponent;

  // State for managing the Bill of Materials selection
  List<RawMaterials> _allRawMaterials = [];
  Map<int, RawMaterials> _selectedMaterialsMap = {};
  Map<int, TextEditingController> _materialQuantityControllers = {};

  List<Good> _allGoods = [];
  Map<int, Good> _selectedComponentGoods = {};
  Map<int, TextEditingController> _goodQuantityControllers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with the existing good's data
    _nameController = TextEditingController(text: widget.good.name);
    _quantityController = TextEditingController(text: widget.good.quantity.toString());
    _priceController = TextEditingController(text: widget.good.price.toString());
    _descriptionController = TextEditingController(text: widget.good.description);
    _isComponent = widget.good.isComponent;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final materials = await _dbHelper.getAllRawMaterials();
    final goods = (await _dbHelper.getAllGoods()).where((g) => g.goodsId != widget.good.goodsId).toList();

    // Fetch the existing BOM for this good
    final materialBomEntries = await _dbHelper.getRawMaterialBOMForGood(widget.good.goodsId!);
    final goodBomEntries = await _dbHelper.getGoodsBOMForGood(widget.good.goodsId!);

    if (mounted) {
      setState(() {
        _allRawMaterials = materials;
        _allGoods = goods;
        // Pre-populate selections for raw materials
        for (var entry in materialBomEntries) {
          final material = materials.firstWhere((m) => m.materialID == entry.rawMaterialId);
          _selectedMaterialsMap[entry.rawMaterialId] = material;
          _materialQuantityControllers[entry.rawMaterialId] = TextEditingController(text: entry.quantityNeeded.toString());
        }
        // Pre-populate selections for component goods
         for (var entry in goodBomEntries) {
          final good = goods.firstWhere((g) => g.goodsId == entry.componentGoodId);
          _selectedComponentGoods[entry.componentGoodId] = good;
          _goodQuantityControllers[entry.componentGoodId] = TextEditingController(text: entry.quantityNeeded.toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _materialQuantityControllers.forEach((_, c) => c.dispose());
    _goodQuantityControllers.forEach((_, c) => c.dispose());
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
                    ? const Text('未找到半成品. 请先添加半成品. ')
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

  Future<void> _updateAll() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Add validation for BOM quantities...

    setState(() { _isLoading = true; });

    try {
      final updatedGood = widget.good.copyWith(
        name: _nameController.text,
        quality: int.parse(_quantityController.text),
        price: double.tryParse(_priceController.text),
        description: _descriptionController.text,
        isComponent: _isComponent, // Include the updated boolean value
      );

      final materialBomEntries = _selectedMaterialsMap.keys.map((materialId) {
        final quantity = int.parse(_materialQuantityControllers[materialId]!.text);
        return BillOfMaterialEntry(goodsId: updatedGood.goodsId!, rawMaterialId: materialId, quantityNeeded: quantity);
      }).toList();
      
      final goodBomEntries = _selectedComponentGoods.keys.map((goodId) {
          final quantity = int.parse(_goodQuantityControllers[goodId]!.text);
          return GoodBOMEntry(finalGoodId: updatedGood.goodsId!, componentGoodId: goodId, quantityNeeded: quantity);
      }).toList();

      await _dbHelper.updateGoodAndBOM(updatedGood, materialBomEntries, goodBomEntries);

      _showSnackBar('商品更新成功!');
      if (mounted) Navigator.pop(context, true); // Pop with success

    } catch (e) {
      _showSnackBar('An error occurred: $e', isError: true);
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelectedMaterials = _selectedMaterialsMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑商品'),
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

                Text('所需原料 (可选)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text('选择原料...'),
                  onPressed: _showMaterialSelectionDialog,
                ),
                const SizedBox(height: 16),
                
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
                  onPressed: _isLoading ? null : _updateAll,
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
