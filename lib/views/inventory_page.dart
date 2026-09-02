import 'package:flutter/material.dart';
import 'dart:async';
import '../services/odoo_client.dart';
import 'product_detail_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.client, required this.url});
  final OdooClient client;
  final String url;
  @override State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> products;
  Timer? _syncTimer;
  @override void initState() { super.initState(); products = widget.client.getInventoryProducts(widget.url); _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) reload(); }); }
  void reload() {
    final nextProducts = widget.client.getInventoryProducts(widget.url, query: search.text);
    setState(() {
      products = nextProducts;
    });
  }
  @override void dispose() { _syncTimer?.cancel(); search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inventaire'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: SearchBar(controller: search, hintText: 'Nom, référence ou code-barres', leading: const Icon(Icons.search), trailing: <Widget>[if (search.text.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () { search.clear(); reload(); })], onChanged: (_) => setState(() {}), onSubmitted: (_) => reload())),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: products, builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ]));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('Aucun produit ne correspond à la recherche.'));
        return GridView.builder(cacheExtent: 600, addAutomaticKeepAlives: false, addSemanticIndexes: false, padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 330, mainAxisExtent: 170, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: list.length, itemBuilder: (_, i) {
          final p = list[i];
          final uom = p['uom_id'] is List && (p['uom_id'] as List).length > 1 ? p['uom_id'][1] : 'Unités';
          return Card(child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductDetailPage(client: widget.client, url: widget.url, productId: (p['id'] as num).toInt()))), child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis), Text('[${p['default_code'] ?? ''}]'), const Spacer(), Text('Prix : ${p['list_price'] ?? 0} €'), Text('En stock : ${p['qty_available'] ?? 0} $uom')]))));
        });
      }))
    ]),
  );
}
