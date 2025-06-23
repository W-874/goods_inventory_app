// lib/pages/edit_good_page.dart
import 'package:flutter/material.dart';
import '../lib/database_helper.dart';
import '../lib/data_class.dart';
import '../lib/db_constants.dart';

class EditGoodPage extends StatefulWidget {
  final Goods good;

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

  // State for managing the Bill of Materials selection
  List<RawMaterials> _allRawMaterials = [];
  Map<int, RawMaterials> _selectedMaterialsMap = {};
  Map<int, TextEditingController> _quantityNeededControllers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with the existing good's data
    _nameController = TextEditingController(text: widget.good.name);
    _quantityController = TextEditingController(text: widget.good.quality.toString());
    _priceController = TextEditingController(text: widget.good.price.toString());
    _descriptionController = TextEditingController(text: widget.good.description);

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final materials = await _dbHelper.getAllRawMaterials();
    final bomEntries = await _dbHelper.getBillOfMaterialEntriesForGood(widget.good.goodsID!);

    if (mounted) {
      setState(() {
        _allRawMaterials = materials;
        for (var entry in bomEntries) {
          final material = materials.firstWhere((m) => m.materialID == entry.rawMaterialId);
          _selectedMaterialsMap[entry.rawMaterialId] = material;
          _quantityNeededControllers[entry.rawMaterialId] = TextEditingController(text: entry.quantityNeeded.toString());
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
    for (var controller in _quantityNeededControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- [ _showSnackBar and _showMaterialSelectionDialog methods are identical to add_good_page ] ---
  void _showSnackBar(String message, {bool isError = false}) { /* ... */ }
  Future<void> _showMaterialSelectionDialog() async { /* ... */ }


  Future<void> _updateAll() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
        _showSnackBar('Please fix the errors in the form.', isError: true);
        return;
    }
    for (var controller in _quantityNeededControllers.values) {
        if(controller.text.isEmpty || int.tryParse(controller.text) == null) {
            _showSnackBar('Please enter a valid quantity for all selected materials.', isError: true);
            return;
        }
    }

    setState(() { _isLoading = true; });

    try {
        final updatedGood = widget.good.copyWith(
            name: _nameController.text,
            quality: int.parse(_quantityController.text),
            price: double.parse(_priceController.text),
            description: _descriptionController.text,
        );
        
        // This will update the good and its BOM in a single transaction
        await _dbHelper.updateGoodAndBOM(
            updatedGood,
            _selectedMaterialsMap.keys.map((materialId) {
                final quantity = int.parse(_quantityNeededControllers[materialId]!.text);
                return BillOfMaterialEntry(
                    goodsId: updatedGood.goodsID!,
                    rawMaterialId: materialId,
                    quantityNeeded: quantity,
                );
            }).toList(),
        );

      _showSnackBar('Good updated successfully!');
      if(mounted) Navigator.pop(context);

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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: '商品价格', border: OutlineInputBorder(), prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? '请输入有效价格' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '商品描述 (可选)', border: OutlineInputBorder()),
                  maxLines: 3,
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
                                controller: _quantityNeededControllers[material.materialID],
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
