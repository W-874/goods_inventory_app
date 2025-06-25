// lib/pages/raw_material_detail_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'edit_raw_material_page.dart'; // Import the edit page

class RawMaterialDetailPage extends StatefulWidget {
  final RawMaterials material;

  const RawMaterialDetailPage({super.key, required this.material});

  @override
  State<RawMaterialDetailPage> createState() => _RawMaterialDetailPageState();
}

class _RawMaterialDetailPageState extends State<RawMaterialDetailPage> {
  final dbHelper = DatabaseHelper.instance;
  late RawMaterials _currentMaterial;

  @override
  void initState() {
    super.initState();
    _currentMaterial = widget.material;
  }

  Future<void> _refreshMaterial() async {
    final material = await dbHelper.getRawMaterial(_currentMaterial.materialID!);
    if (material != null && mounted) {
      setState(() {
        _currentMaterial = material;
      });
    }
  }

  Future<void> _showUpdateQuantityDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('为 ${_currentMaterial.name} 更新数量'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前数量: ${_currentMaterial.quality}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '修改 (+/-)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入数量';
                    final change = int.tryParse(value);
                    if (change == null) return '请输入有效的数字';
                    if (_currentMaterial.quality + change < 0) return '库存不能为负';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: const Text('保存'),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final change = int.tryParse(controller.text) ?? 0;
                  final updatedMaterial = _currentMaterial.copyWith(quality: _currentMaterial.quality + change);
                  await dbHelper.updateRawMaterial(updatedMaterial);
                  Navigator.of(context).pop();
                  _refreshMaterial();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('你确定吗?'),
        content: const Text('这将永远删除该原材料. 这将会影响商品所使用的原料.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMaterial.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('详细信息', style: textTheme.titleLarge),
                      const Divider(),
                      Text('ID: ${_currentMaterial.materialID}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${_currentMaterial.quality}', style: textTheme.bodyLarge),
                      if (_currentMaterial.description != null && _currentMaterial.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('描述: ${_currentMaterial.description}', style: textTheme.bodyLarge),
                      ],
                      const SizedBox(height: 16),
                      // --- ACTION BUTTONS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                            IconButton(
                                icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                                tooltip: '更新数量',
                                onPressed: _showUpdateQuantityDialog,
                            ),
                            IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: '删除',
                                onPressed: () async {
                                    if (await _showDeleteConfirmationDialog()) {
                                        await dbHelper.deleteRawMaterial(_currentMaterial.materialID!);
                                        if (mounted) Navigator.pop(context, true); // Pop with success
                                    }
                                },
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('涉及的商品', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getBOMEntriesForRawMaterialWithGoodNames(_currentMaterial.materialID!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('该原材料没有被使用.');
                  }
                  return Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final bomEntry = snapshot.data![index];
                        return ListTile(
                          // Display the Good's name and the quantity needed
                          title: Text(bomEntry.goodName ?? 'Unknown Good'),
                          trailing: Text('Qty Needed: ${bomEntry.quantityNeeded}'),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // --- NEW EDIT BUTTON ---
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('编辑详情'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditRawMaterialPage(material: _currentMaterial)),
                  );
                  if (result == true && mounted) {
                    _refreshMaterial();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
