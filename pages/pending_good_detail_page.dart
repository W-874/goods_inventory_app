// lib/pages/pending_good_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';

class PendingGoodDetailPage extends StatefulWidget {
  final PendingGood pendingGood;

  const PendingGoodDetailPage({super.key, required this.pendingGood});

  @override
  State<PendingGoodDetailPage> createState() => _PendingGoodDetailPageState();
}

class _PendingGoodDetailPageState extends State<PendingGoodDetailPage> {
  final dbHelper = DatabaseHelper.instance;
  bool _isLoading = false;
  bool _hasChanges = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  Future<bool> _showConfirmationDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// New dialog to handle quantity input for In Store actions.
  Future<void> _showInStoreActionDialog({required bool isStocking}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final action = isStocking ? '入库' : '出库';
    final goodName = widget.pendingGood.goodName ?? '物品';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$action Quantity for $goodName'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('剩余待出库: ${widget.pendingGood.quantityInProduction}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Quantity to $action',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a quantity';
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) return 'Please enter a positive number';
                    if (qty > widget.pendingGood.quantityInProduction) return 'Cannot $action more than available';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: Text(action),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final quantity = int.parse(controller.text);
                  try {
                    if (isStocking) {
                      await dbHelper.stockInStoreGood(widget.pendingGood, quantity);
                    } else {
                      await dbHelper.exportInStoreGood(widget.pendingGood, quantity);
                    }
                    _hasChanges = true;
                    if(mounted) Navigator.of(context).pop(); // Close the dialog
                  } catch (e) {
                     if(mounted) _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    if (widget.pendingGood.isUnderConstruction) {
      // --- Actions for "In Production" items ---
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('取消'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                if (await _showConfirmationDialog(
                    title: '取消生产?', 
                    content: '这将会返还原材料到原材料库存中.'
                )) {
                  await dbHelper.cancelProduction(widget.pendingGood);
                  if(mounted) Navigator.pop(context, true); // Pop with success signal
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('完成'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                 if (await _showConfirmationDialog(
                    title: '生产已完成?', 
                    content: '这将会把 ${widget.pendingGood.quantityInProduction} 个 "${widget.pendingGood.goodName}" 加入到待入库清单中.'
                )) {
                    await dbHelper.completeProduction(widget.pendingGood);
                    if(mounted) Navigator.pop(context, true); // Pop with success signal
                }
              },
            ),
          ),
        ],
      );
    } else {
      // --- Actions for "In Store" items ---
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.local_shipping_outlined, color: Theme.of(context).colorScheme.primary),
              label: const Text('出库'),
              onPressed: () => _showInStoreActionDialog(isStocking: false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.inventory_outlined),
              label: const Text('入库'),
              onPressed: () => _showInStoreActionDialog(isStocking: true),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final formattedDate = DateFormat.yMd().add_jm().format(widget.pendingGood.startDate);
    final statusText = widget.pendingGood.isUnderConstruction ? '生产中' : '待入库';
    final statusColor = widget.pendingGood.isUnderConstruction ? Colors.blue.shade700 : Colors.green.shade700;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pendingGood.goodName ?? '生产详情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context, _hasChanges);
          },
        ),        
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('详情', style: textTheme.titleLarge),
                      const Divider(),
                      Text('商品名称: ${widget.pendingGood.goodName}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${widget.pendingGood.quantityInProduction}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('时间: $formattedDate', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('生产状态: ', style: textTheme.bodyLarge),
                          Text(statusText, style: textTheme.bodyLarge?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                  const Center(child: CircularProgressIndicator())
              else
                  _buildActionButtons(),
              const SizedBox(height: 24),
              Text('消耗的原材料', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getRawMaterialBOMForGood(widget.pendingGood.goodsId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('不能确定消耗的原材料.');
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
                          trailing: Text('总消耗: ${bomEntry.quantityNeeded * widget.pendingGood.quantityInProduction}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
