// lib/pages/pending_good_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../lib/dataClass.dart';
import '../lib/databaseHelper.dart';

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
                      Text('Production Order Details', style: textTheme.titleLarge),
                      const Divider(),
                      Text('Producing: ${pendingGood.goodName}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Quantity: ${pendingGood.quantityInProduction}', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Started: $formattedDate', style: textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Status: In Production', style: textTheme.bodyLarge?.copyWith(color: Colors.blue.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Consumed Raw Materials', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<BillOfMaterialEntry>>(
                future: dbHelper.getBillOfMaterialsWithNames(pendingGood.goodsId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Could not determine consumed materials.');
                  }
                  return Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final bomEntry = snapshot.data![index];
                        return ListTile(
                          title: Text(bomEntry.rawMaterialName ?? 'Unknown Material'),
                          trailing: Text('Total Used: ${bomEntry.quantityNeeded * pendingGood.quantityInProduction}'),
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
