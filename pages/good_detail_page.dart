// lib/pages/good_detail_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';
import './edit_good_page.dart'; // Import the edit page

class GoodDetailPage extends StatefulWidget {
  final Goods good;

  const GoodDetailPage({super.key, required this.good});

  @override
  State<GoodDetailPage> createState() => _GoodDetailPageState();
}

class _GoodDetailPageState extends State<GoodDetailPage> {
  final dbHelper = DatabaseHelper.instance;
  late Goods _currentGood;

  @override
  void initState() {
    super.initState();
    _currentGood = widget.good;
  }

  // Helper method to refresh the good's data from the database
  Future<void> _refreshGood() async {
    final good = await dbHelper.getGood(_currentGood.goodsID!);
    if (good != null && mounted) {
      setState(() {
        _currentGood = good;
      });
    }
  }
  
  // Reusable dialog for updating quantity
  Future<void> _showUpdateQuantityDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('为 ${_currentGood.name} 更新数量'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前数量: ${_currentGood.quality}'),
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
                    if (_currentGood.quality + change < 0) return '库存不能为负';
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
                  final updatedGood = _currentGood.copyWith(quality: _currentGood.quality + change);
                  await dbHelper.updateGood(updatedGood);
                  Navigator.of(context).pop();
                  _refreshGood();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Reusable dialog for confirming deletion
  Future<bool> _showDeleteConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('你确定吗?'),
        content: const Text('这将永远删除该商品及其所有相关生产数据!'),
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
        title: Text(_currentGood.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Add padding for FAB replacement
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
                      Text('ID: ${_currentGood.goodsID}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${_currentGood.quality}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Price: \$${_currentGood.price?.toStringAsFixed(2) ?? 'N/A'}', style: textTheme.bodyLarge),
                      if (_currentGood.description != null && _currentGood.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('描述: ${_currentGood.description}', style: textTheme.bodyLarge),
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
                                        await dbHelper.deleteGood(_currentGood.goodsID!);
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
              Text('需求的原料', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getBillOfMaterialsWithNames(_currentGood.goodsID!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('该商品不需要原料.');
                  }
                  return Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final bomEntry = snapshot.data![index];
                        return ListTile(
                          title: Text(bomEntry.rawMaterialName ?? '未知原料'),
                          trailing: Text('数量: ${bomEntry.quantityNeeded}'),
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
                  // Making the button stand out a bit more
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () async {
                  // Navigate to the edit page and wait for a result
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditGoodPage(good: _currentGood)),
                  );
                  // If the edit page pops with 'true', refresh the data
                  if (result == true && mounted) {
                    _refreshGood();
                  }
                },
              ),
            ],
          ),
        ),
      ),
      // --- REMOVED FloatingActionButton ---
    );
  }
}
