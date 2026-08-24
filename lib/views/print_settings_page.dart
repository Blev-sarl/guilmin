import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class PrintSettingsPage extends StatefulWidget {
  const PrintSettingsPage({super.key});
  @override State<PrintSettingsPage> createState() => _PrintSettingsPageState();
}

class _PrintSettingsPageState extends State<PrintSettingsPage> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '9100');
  String _template = 'normal';
  bool _withPrice = false;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final v = await PreferencesService().loadZplPrinter();
    if (!mounted) return;
    setState(() { _ip.text = v['ip'] as String; _port.text = '${v['port']}'; _template = v['template'] as String; _withPrice = v['withPrice'] as bool; _loading = false; });
  }
  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (_ip.text.trim().isEmpty || port == null || port < 1 || port > 65535) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adresse IP et port invalides'))); return; }
    await PreferencesService().saveZplPrinter(ip: _ip.text.trim(), port: port, template: _template, withPrice: _withPrice);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paramètres enregistrés')));
  }
  @override void dispose() { _ip.dispose(); _port.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('Paramètres d’impression')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Imprimante Zebra ZPL', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      TextField(controller: _ip, decoration: const InputDecoration(labelText: 'Adresse IP')), const SizedBox(height: 12),
      TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port TCP', hintText: '9100')), const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _template, decoration: const InputDecoration(labelText: 'Modèle ZPL'), items: const [
        DropdownMenuItem(value: 'normal', child: Text('Normal (2,25 x 1,25)')), DropdownMenuItem(value: 'small', child: Text('Petit (1,25 x 1,00)')), DropdownMenuItem(value: 'alternative', child: Text('Alternative (2,00 x 1,00)')), DropdownMenuItem(value: 'jewelry', child: Text('Bijoux (2,20 x 0,50)')),
      ], onChanged: (v) => setState(() => _template = v ?? 'normal')),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Imprimer avec le prix'), value: _withPrice, onChanged: (v) => setState(() => _withPrice = v)), const SizedBox(height: 16),
      FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
    ]));
  }
}
