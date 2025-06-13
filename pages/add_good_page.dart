// lib/pages/add_good_page.dart
import 'package:flutter/material.dart';
import '../lib/databaseHelper.dart';
import '../lib/dataClass.dart';

class AddGoodPage extends StatefulWidget {
  const AddGoodPage({super.key});

  @override
  State<AddGoodPage> createState() => _AddGoodPageState();
}

class _AddGoodPageState extends State<AddGoodPage> {
  // A global key that uniquely identifies the Form widget and allows validation.
  final _formKey = GlobalKey<FormState>();

  // Controllers to manage the text being edited in the TextFormFields.
  final _goodsIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _goodsIdController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
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

  Future<void> _saveGood() async {
    // First, validate the form.
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        // If the ID field is empty, tryParse returns null. We use 0 as a
        // sentinel value for the database helper to indicate a new entry
        // for an autoincrementing ID.
        final int goodsId = int.tryParse(_goodsIdController.text) ?? 0;

        // Create a Good object from the form data.
        final good = Goods(
          goodsID: goodsId,
          name: _nameController.text,
          quality: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
        );

        // Access the database and create the record.
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.createGood(good);
        
        _showSnackBar('Good "${good.name}" saved successfully!');
        
        // Clear the form fields after successful save.
        _formKey.currentState?.reset();
        _goodsIdController.clear();
        _nameController.clear();
        _quantityController.clear();
        _priceController.clear();
        _descriptionController.clear();

      } catch (e) {
        // Provide a more user-friendly error for unique constraint violations
        if (e.toString().contains('UNIQUE constraint failed')) {
          _showSnackBar('Error: A good with this ID already exists.', isError: true);
        } else {
          _showSnackBar('Error saving good: $e', isError: true);
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Good'),
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
                // Goods ID Field (now optional)
                TextFormField(
                  controller: _goodsIdController,
                  decoration: const InputDecoration(
                    labelText: 'Goods ID (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Leave empty for auto-generation',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    // It's optional, so empty is fine. But if a value is provided, it must be a number.
                    if (value != null &&
                        value.isNotEmpty &&
                        int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Deluxe Widget',
                  ),
                   textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Quantity Field
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Remaining Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Price Field
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field (Optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  // No validator needed as it's optional.
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveGood,
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
                      : const Text('Save Good'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
