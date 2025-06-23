// lib/pages/good_detail_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';

class GoodDetailPage extends StatelessWidget {
  final Goods good;

  const GoodDetailPage({super.key, required this.good});

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper.instance;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(good.name),
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
                      Text('ID: ${good.goodsID}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${good.quality}', style: textTheme.bodyLarge),
                      if (good.description != null && good.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('描述: ${good.description}', style: textTheme.bodyLarge),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('需求的原料', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getBillOfMaterialsWithNames(good.goodsID!),
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
            ],
          ),
        ),
      ),
    );
  }
}
