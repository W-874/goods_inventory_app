// lib/pages/pending_good_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:goods_inventory_app/data_class.dart';
import 'package:goods_inventory_app/database_helper.dart';

class PendingGoodDetailPage extends StatelessWidget {
  final PendingGood pendingGood;

  const PendingGoodDetailPage({super.key, required this.pendingGood});

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper.instance;
    final textTheme = Theme.of(context).textTheme;
    final formattedDate = DateFormat.yMd().add_jm().format(pendingGood.startDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(pendingGood.goodName ?? 'Pending Production'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                      Text('详细信息', style: textTheme.titleLarge),
                      const Divider(),
                      Text('正在生产: ${pendingGood.goodName}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${pendingGood.quantityInProduction}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('开始于: $formattedDate', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('状态：正在生产', style: textTheme.bodyLarge?.copyWith(color: Colors.blue.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('消耗的原料', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getBillOfMaterialsWithNames(pendingGood.goodsId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('不能确定消耗的原料.');
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
                          trailing: Text('共消耗: ${bomEntry.quantityNeeded * pendingGood.quantityInProduction}'),
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
