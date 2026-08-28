import 'package:flutter/material.dart';
import '../models/stock_operation.dart';
import '../services/odoo_client.dart';
import 'operation_detail_page.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({
    super.key,
    required this.client,
    required this.url,
  });
  final OdooClient client;
  final String url;
  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  late Future<List<Map<String, dynamic>>> _orders;
  final _search = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
    _orders = widget.client.getPurchaseOrders(widget.url);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _partner(dynamic v) =>
      v is List && v.length > 1 ? v[1].toString() : 'Fournisseur';
  String _ref(dynamic v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : 'Non renseignée';
  String _state(dynamic v) =>
      <String, String>{
        'draft': 'Demande de prix',
        'sent': 'Demande de prix envoyée',
        'to approve': 'À approuver',
        'purchase': 'Bon de commande',
        'done': 'Terminé',
        'cancel': 'Annulé',
      }[v.toString()] ??
      v.toString();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bons de commande')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _orders,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final q = _query.toLowerCase().trim();
        final list = snap.data!
            .where(
              (o) =>
                  q.isEmpty ||
                  '${o['name']} ${_partner(o['partner_id'])} ${_ref(o['partner_ref'])}'
                      .toLowerCase()
                      .contains(q),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Rechercher',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final o = list[i];
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: ListTile(
                      titleAlignment: ListTileTitleAlignment.center,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseOrderDetailPage(
                            client: widget.client,
                            url: widget.url,
                            order: o,
                          ),
                        ),
                      ),
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        '${o['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_partner(o['partner_id'])}\nRéf. fournisseur : ${_ref(o['partner_ref'])}\nStatut : ${_state(o['state'])}',
                      ),
                      isThreeLine: true,
                      trailing: const SizedBox(
                        width: 32,
                        child: Center(child: Icon(Icons.chevron_right)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PurchaseOrderDetailPage extends StatelessWidget {
  const PurchaseOrderDetailPage({
    super.key,
    required this.client,
    required this.url,
    required this.order,
  });
  final OdooClient client;
  final String url;
  final Map<String, dynamic> order;
  String _money(dynamic v) => v is num ? v.toStringAsFixed(2) : '0.00';
  String _rel(dynamic v) =>
      v is List && v.length > 1 ? v[1].toString() : 'Non renseigné';
  String _date(dynamic v) {
    final d = DateTime.tryParse(v?.toString().replaceFirst(' ', 'T') ?? '');
    if (d == null) return 'Non renseignée';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _state(dynamic v) =>
      <String, String>{
        'draft': 'Demande de prix',
        'sent': 'Demande de prix envoyée',
        'to approve': 'À approuver',
        'purchase': 'Bon de commande',
        'done': 'Terminé',
        'cancel': 'Annulé',
      }[v.toString()] ??
      v.toString();
  Widget _line(Map<String, dynamic> l) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(
        _rel(l['product_id']),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${l['name'] ?? ''}\nQuantité : ${l['product_qty'] ?? 0} ${_rel(l['product_uom_id'])}\nPrix unitaire : ${_money(l['price_unit'])} €',
      ),
      trailing: Text('${_money(l['price_subtotal'])} €'),
    ),
  );
  Widget _delivery(BuildContext context, Map<String, dynamic> d) {
    final operation = StockOperation.fromJson(<String, dynamic>{
      ...d,
      'origin': order['name'],
      'partner_id': order['partner_id'],
    });
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.center,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OperationDetailPage(
              client: client,
              url: url,
              operation: operation,
            ),
          ),
        ),
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(
          '${d['name'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'État : ${_state(d['state'])}\nDate prévue : ${_date(d['scheduled_date'])}\nDestination : ${_rel(d['location_dest_id'])}',
        ),
        isThreeLine: true,
        trailing: const SizedBox(
          width: 32,
          child: Center(child: Icon(Icons.chevron_right)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${order['name']}')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: client.getPurchaseOrderLines(url, (order['id'] as num).toInt()),
      builder: (context, snap) {
        final lines = snap.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order['name']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Fournisseur : ${_rel(order['partner_id'])}'),
                    Text(
                      'Référence fournisseur : ${order['partner_ref'] ?? 'Non renseignée'}',
                    ),
                    Text('Statut : ${_state(order['state'])}'),
                    Text('Date : ${_date(order['date_order'])}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Livraisons liées',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: client.getPurchaseOrderDeliveries(
                url,
                (order['id'] as num).toInt(),
              ),
              builder: (context, ds) {
                final deliveries = ds.data ?? <Map<String, dynamic>>[];
                return Column(
                  children: [for (final d in deliveries) _delivery(context, d)],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Lignes du bon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            if (snap.hasError) Text('Erreur : ${snap.error}'),
            for (final line in lines) _line(line),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Total : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_money(order['amount_total'])} €', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
