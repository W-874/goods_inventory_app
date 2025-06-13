// lib/pages/add_raw_material_page.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../lib/databaseHelper.dart';
import '../lib/dataClass.dart';

class AddRawMaterialPage extends StatefulWidget {
  const AddRawMaterialPage({super.key});

  @override
  State<AddRawMaterialPage> createState() => _AddRawMaterialPageState();
}

class _AddRawMaterialPageState extends State<AddRawMaterialPage> {
  // A global key that uniquely identifies the Form widget and allows validation.
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  // Controllers to manage the text being edited in the TextFormFields.
  final _rawMaterialIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Goods> _allGoods = [];
  Map<int, Goods> _selectedGoodsMap = {}; // Key: goodsId, Value: Good object
  Map<int, TextEditingController> _quantityNeededControllers = {}; // Key: goodsId, Value: Controller

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllGoods();
  }

  Future<void> _loadAllGoods() async {
    final goods = await _dbHelper.getAllGoods();
    setState(() {
      _allGoods = goods;
    });
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _rawMaterialIdController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (var controller in _quantityNeededControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    // Check if the widget is still in the tree.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }
  Future<void> _showGoodsSelectionDialog() async {
    // Use a temporary map to manage selections within the dialog
    Map<int, Goods> tempSelectedGoods = Map.from(_selectedGoodsMap);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Associated Goods'),
              content: SizedBox(
                width: double.maxFinite,
                child: _allGoods.isEmpty
                    ? const Text('No goods found. Please add a good first.')
                    : ListView.builder(
                        itemCount: _allGoods.length,
                        itemBuilder: (context, index) {
                          final good = _allGoods[index];
                          final isSelected = tempSelectedGoods.containsKey(good.goodsID);
                          return CheckboxListTile(
                            title: Text(good.name),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelectedGoods[good.goodsID!] = good;
                                } else {
                                  tempSelectedGoods.remove(good.goodsID);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedGoodsMap = tempSelectedGoods;
                      // Create controllers for new selections and dispose of old ones
                      final oldKeys = _quantityNeededControllers.keys.toSet();
                      final newKeys = _selectedGoodsMap.keys.toSet();
                      
                      final keysToRemove = oldKeys.difference(newKeys);
                      for (var key in keysToRemove) {
                        _quantityNeededControllers[key]?.dispose();
                        _quantityNeededControllers.remove(key);
                      }

                      for (var key in newKeys) {
                        if (!_quantityNeededControllers.containsKey(key)) {
                          _quantityNeededControllers[key] = TextEditingController();
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAll() async {
    // Validate the main form first
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('Please fix the errors in the form.', isError: true);
      return;
    }
    
    // Also validate that if goods are selected, their quantities are entered
    for (var controller in _quantityNeededControllers.values) {
        if(controller.text.isEmpty || int.tryParse(controller.text) == null) {
            _showSnackBar('Please enter a valid quantity for all selected goods.', isError: true);
            return;
        }
    }

    setState(() { _isLoading = true; });

    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        // --- Part 1: Create the Raw Material ---
        final rawMaterialIdFromForm = int.tryParse(_rawMaterialIdController.text);
        
        final newRawMaterial = RawMaterials(
          materialID: rawMaterialIdFromForm ?? 0,
          name: _nameController.text,
          quality: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
        );

        int newRawMaterialId;
        if (rawMaterialIdFromForm != null) {
          // User specified an ID
          await txn.insert(tableRawMaterials, newRawMaterial.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
          newRawMaterialId = rawMaterialIdFromForm;
        } else {
          // Autoincrement the ID
          newRawMaterialId = await txn.insert(tableRawMaterials, newRawMaterial.toMap(forInsertAndAutoincrement: true));
        }

        if (newRawMaterialId <= 0) {
          throw Exception("Failed to create the new raw material.");
        }

        // --- Part 2: Create Bill of Material Entries ---
        for (final goodId in _selectedGoodsMap.keys) {
          final quantity = int.parse(_quantityNeededControllers[goodId]!.text);
          final bomEntry = BillOfMaterialEntry(
            goodsId: goodId,
            rawMaterialId: newRawMaterialId, // Use the ID of the material just created
            quantityNeeded: quantity,
          );
          // Use replace to handle cases where this relationship might already exist
          await txn.insert(tableBillOfMaterials, bomEntry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      _showSnackBar('Raw Material "${_nameController.text}" saved successfully!');
      
      // Clear all forms and state
      _formKey.currentState?.reset();
      _rawMaterialIdController.clear();
      _nameController.clear();
      _quantityController.clear();
      _priceController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedGoodsMap.clear();
        for (var controller in _quantityNeededControllers.values) {
          controller.dispose();
        }
        _quantityNeededControllers.clear();
      });

    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed') || e.toString().contains('ConflictAlgorithm.fail')) {
        _showSnackBar('Error: A raw material with this ID already exists.', isError: true);
      } else {
        _showSnackBar('An error occurred: $e', isError:true);
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create a sorted list of selected goods for stable UI rendering
    final sortedSelectedGoods = _selectedGoodsMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Raw Material'),
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
                Text('Raw Material Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rawMaterialIdController,
                  decoration: const InputDecoration(labelText: 'Raw Material ID (Optional)', border: OutlineInputBorder(), hintText: 'Leave empty to auto-generate'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.isNotEmpty && int.tryParse(v) == null ? 'Must be a valid number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? 'Please enter a valid quantity' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder(), prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? 'Please enter a valid price' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                  maxLines: 3,
                  // No validator needed as it's optional.
                ),
                const Divider(height: 40, thickness: 1),

                // --- Bill of Materials Section ---
                Text('Component In (Optional)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text('Select Goods...'),
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

                // --- Submit Button ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAll,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Raw Material'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
