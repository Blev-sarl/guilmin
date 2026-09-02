import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/login_controller.dart';
import 'login_page.dart';
import 'reception_types_page.dart';
import 'inventory_page.dart';
import 'packages_page.dart';
import 'purchase_orders_page.dart';
import 'print_settings_page.dart';
import 'update_dialog.dart';
import 'widgets/app_version_label.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});
  final LoginController controller;
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _prefKey = 'dashboard_menu_order';
  final _defaultOrder = <String>['operations', 'inventory', 'packages', 'orders'];
  late List<String> _order;
  bool _editing = false;

  @override
  void initState() { super.initState(); _order = List<String>.from(_defaultOrder); _loadOrder(); }
  Future<void> _loadOrder() async { final p = await SharedPreferences.getInstance(); final v = p.getStringList(_prefKey); if (v != null && mounted) setState(() => _order = v); }
  Future<void> _saveOrder() async { final p = await SharedPreferences.getInstance(); await p.setStringList(_prefKey, _order); }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    if (user == null || widget.controller.url == null) return LoginPage(controller: widget.controller);
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/guilmin_logo.png', width: 145, height: 42, fit: BoxFit.contain), actions: <Widget>[
        IconButton(tooltip: _editing ? 'Terminer' : 'Modifier l’ordre', onPressed: () => setState(() => _editing = !_editing), icon: Icon(_editing ? Icons.check : Icons.sort)),
        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrintSettingsPage())), icon: const Icon(Icons.print_outlined)),
        IconButton(onPressed: () => showUpdateDialog(context), icon: const Icon(Icons.system_update_outlined)),
        IconButton(onPressed: () { widget.controller.logout(); Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => LoginPage(controller: widget.controller))); }, icon: const Icon(Icons.logout)),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: <Widget>[
        Text('Bonjour ${user.name.isEmpty ? user.login : user.name}', style: Theme.of(context).textTheme.headlineSmall),
        const Align(alignment: Alignment.centerLeft, child: AppVersionLabel()), const SizedBox(height: 24),
        if (_editing) const Text('Maintenez un menu puis déplacez-le.'),
        if (_editing)
          ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _order.length, proxyDecorator: (child, index, animation) => child, onReorder: (oldIndex, newIndex) { setState(() { if (newIndex > oldIndex) newIndex--; final item = _order.removeAt(oldIndex); _order.insert(newIndex, item); }); _saveOrder(); }, itemBuilder: (_, i) => KeyedSubtree(key: ValueKey(_order[i]), child: Column(children: <Widget>[_card(_order[i]), if (i < _order.length - 1) const SizedBox(height: 8)])))
        else
          ..._order.expand((id) => <Widget>[_card(id), const SizedBox(height: 8)]),
      ]),
    );
  }

  Widget _card(String id) {
    final map = <String, dynamic>{'operations': ['Opérations', 'Réceptions, livraisons et transferts internes', Icons.qr_code_scanner, (BuildContext c) => ReceptionTypesPage(client: widget.controller.client, url: widget.controller.url!)], 'inventory': ['Inventaire', 'Consulter les stocks et les emplacements', Icons.inventory_outlined, (BuildContext c) => InventoryPage(client: widget.controller.client, url: widget.controller.url!)], 'packages': ['Colis', 'Consulter et créer des colis', Icons.inventory_2_outlined, (BuildContext c) => PackagesPage(client: widget.controller.client, url: widget.controller.url!)], 'orders': ['Bons de commande', 'Consulter les bons de commande fournisseurs', Icons.receipt_long_outlined, (BuildContext c) => PurchaseOrdersPage(client: widget.controller.client, url: widget.controller.url!)]}[id]!;
    return Card(child: ListTile(leading: Icon(map[2] as IconData, size: 36), title: Text(map[0] as String, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(map[1] as String), trailing: _editing ? null : const Icon(Icons.chevron_right), onTap: _editing ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => map[3](context)))));
  }
}
