// lib/pages/edit_raw_material_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';

class EditRawMaterialPage extends StatefulWidget {
  final RawMaterials material;

  const EditRawMaterialPage({super.key, required this.material});

  @override
  State<EditRawMaterialPage> createState() => _EditRawMaterialPageState();
}

class _EditRawMaterialPageState extends State<EditRawMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  // State for managing which goods this material is a component of
  List<Goods> _allGoods = [];
  Map<int, Goods> _selectedGoodsMap = {};
  Map<int, TextEditingController> _quantityNeededControllers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material.name);
    _quantityController = TextEditingController(text: widget.material.quality.toString());
    _priceController = TextEditingController(text: widget.material.price.toString());
    _descriptionController = TextEditingController(text: widget.material.description);
    
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
      final goods = await _dbHelper.getAllGoods();
      final bomEntries = await _dbHelper.getBillOfMaterialEntriesForRawMaterial(widget.material.materialID!);

      if (mounted) {
          setState(() {
              _allGoods = goods;
              for (var entry in bomEntries) {
                  final good = goods.firstWhere((g) => g.goodsID == entry.goodsId);
                  _selectedGoodsMap[entry.goodsId] = good;
                  _quantityNeededControllers[entry.goodsId] = TextEditingController(text: entry.quantityNeeded.toString());
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
    _quantityNeededControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // --- [ _showSnackBar and _showGoodsSelectionDialog methods are similar to add_raw_material_page ] ---
  void _showSnackBar(String message, {bool isError = false}) { /* ... */ }
  Future<void> _showGoodsSelectionDialog() async { /* ... */ }


  Future<void> _updateAll() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
        _showSnackBar('Please fix the errors in the form.', isError: true);
        return;
    }
    for (var controller in _quantityNeededControllers.values) {
        if(controller.text.isEmpty || int.tryParse(controller.text) == null) {
            _showSnackBar('Please enter a valid quantity for all selected goods.', isError: true);
            return;
        }
    }

    setState(() { _isLoading = true; });

    try {
        final updatedMaterial = widget.material.copyWith(
            name: _nameController.text,
            quality: int.parse(_quantityController.text),
            description: _descriptionController.text,
        );

        await _dbHelper.updateRawMaterialAndBOM(
            updatedMaterial,
            _selectedGoodsMap.keys.map((goodId) {
                final quantity = int.parse(_quantityNeededControllers[goodId]!.text);
                return BillOfMaterialEntry(
                    goodsId: goodId,
                    rawMaterialId: updatedMaterial.materialID!,
                    quantityNeeded: quantity,
                );
            }).toList(),
        );

        _showSnackBar('Raw Material updated successfully!');
        if (mounted) Navigator.pop(context);

    } catch (e) {
        _showSnackBar('An error occurred: $e', isError: true);
    } finally {
      if(mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Create a sorted list of selected goods for stable UI rendering
    final sortedSelectedGoods = _selectedGoodsMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑原料'),
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
                // --- Raw Material Details Section ---
                //Text('新原料细节', style: Theme.of(context).textTheme.titleLarge),
                //const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '原料名称', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.isEmpty ? '请输入名称' : null,
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
                //   decoration: const InputDecoration(labelText: '原料价格', border: OutlineInputBorder(), prefixText: '¥'),
                //   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                //   validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? '请输入有效价格' : null,
                // ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '原料描述 (可选)', border: OutlineInputBorder()),
                  maxLines: 3,
                  // No validator needed as it's optional.
                ),
                const Divider(height: 40, thickness: 1),

                // --- Bill of Materials Section ---
                Text('被什么商品需要？ (可选)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text('选择商品...'),
                  onPressed: _showGoodsSelectionDialog,
                ),
                const SizedBox(height: 16),
                // Display the list of selected goods with quantity input fields
                if (sortedSelectedGoods.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedSelectedGoods.length,
                    itemBuilder: (context, index) {
                      final good = sortedSelectedGoods[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(good.name, style: const TextStyle(fontSize: 16))),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _quantityNeededControllers[good.goodsID],
                                decoration: const InputDecoration(labelText: '需要数量', border: OutlineInputBorder()),
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

                // --- Submit Button ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateAll,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('保存原料'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
