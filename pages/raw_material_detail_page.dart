// lib/pages/raw_material_detail_page.dart
import 'package:flutter/material.dart';
import 'package:goods_inventory_app/database_helper.dart';
import 'package:goods_inventory_app/data_class.dart';

class RawMaterialDetailPage extends StatelessWidget {
  final RawMaterials material;

  const RawMaterialDetailPage({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final dbHelper = DatabaseHelper.instance;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(material.name),
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
                      Text('ID: ${material.materialID}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('数量: ${material.quality}', style: textTheme.bodyLarge),
                      if (material.description != null && material.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('描述: ${material.description}', style: textTheme.bodyLarge),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('被使用于', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<Goods>>(
                future: dbHelper.getGoodsUsingRawMaterial(material.materialID!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('这个原料目前未被任何商品使用.');
                  }
                  return Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final good = snapshot.data![index];
                        return ListTile(
                          title: Text(good.name),
                          trailing: Text('ID: ${good.goodsID}'),
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
