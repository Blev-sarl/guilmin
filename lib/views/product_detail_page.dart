import 'package:flutter/material.dart';
import '../services/odoo_client.dart';
import 'product_locations_page.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.client, required this.url, required this.productId});
  final OdooClient client;
  final String url;
  final int productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produit')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: client.getProductDetails(url, productId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final p = snapshot.data!;
          final unit = p['uom_id'] is List && (p['uom_id'] as List).length > 1 ? p['uom_id'][1] : 'Unités';
          final rows = <String>[
            'Type de produit : ${p['type'] ?? 'Bien'}',
            'Ventes : ${p['sale_ok'] == true ? 'Oui' : 'Non'}',
            'Achats : ${p['purchase_ok'] == true ? 'Oui' : 'Non'}',
            'Prix de vente : ${p['list_price'] ?? 0} € par $unit',
            'Coût : ${p['standard_price'] ?? 0} € par $unit',
            'Quantité en stock : ${p['qty_available'] ?? 0} $unit',
            'Référence : ${p['default_code'] ?? ''}',
            'Code-barres : ${p['barcode'] ?? ''}',
          ];
          return ListView(padding: const EdgeInsets.all(20), children: <Widget>[
            Text('Produit', style: Theme.of(context).textTheme.labelLarge),
            Text('${p['name'] ?? ''}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            ...rows.map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(row))),
            if ((p['qty_available'] as num?)?.toDouble() case final stock? when stock > 0) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductLocationsPage(client: client, url: url, productId: productId, productName: '${p['name'] ?? ''}'))), icon: const Icon(Icons.location_on_outlined), label: const Text('Voir les emplacements')),
            ],
            const SizedBox(height: 24),
            const Text('NOTES INTERNES', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
          ]);
        },
      ),
    );
  }
}
