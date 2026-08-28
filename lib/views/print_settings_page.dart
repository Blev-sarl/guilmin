import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class PrintSettingsPage extends StatefulWidget {
  const PrintSettingsPage({super.key});
  @override State<PrintSettingsPage> createState() => _PrintSettingsPageState();
}

class _PrintSettingsPageState extends State<PrintSettingsPage> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '9100');
  final _width = TextEditingController(text: '71');
  final _height = TextEditingController(text: '107');
  final _dpi = TextEditingController(text: '203');
  String _template = 'normal';
  int _rotation = 0;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final v = await PreferencesService().loadZplPrinter();
    if (!mounted) return;
    setState(() { _ip.text = v['ip'] as String; _port.text = '${v['port']}'; _template = v['template'] as String; _width.text = '${v['widthMm']}'; _height.text = '${v['heightMm']}'; _dpi.text = '${v['dpi']}'; _rotation = (v['rotation'] as int).clamp(0, 360); _loading = false; });
  }
  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    final width = double.tryParse(_width.text.replaceAll(',', '.'));
    final height = double.tryParse(_height.text.replaceAll(',', '.'));
    final dpi = int.tryParse(_dpi.text.trim());
    if (_ip.text.trim().isEmpty || port == null || port < 1 || port > 65535 || dpi == null || (dpi != 203 && dpi != 300) || (_template == 'custom' && (width == null || height == null || width <= 0 || height <= 0))) return;
    await PreferencesService().saveZplPrinter(ip: _ip.text.trim(), port: port, template: _template, withPrice: false, widthMm: width ?? 71, heightMm: height ?? 107, dpi: dpi, rotation: _rotation);
    if (mounted) Navigator.of(context).pop(true);
  }
  @override void dispose() { _ip.dispose(); _port.dispose(); _width.dispose(); _height.dispose(); _dpi.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('Paramètre d’impression ZPL')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Paramètre d’impression ZPL', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
      TextField(controller: _ip, decoration: const InputDecoration(labelText: 'Adresse IP')), const SizedBox(height: 12),
      TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port TCP', hintText: '9100')), const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: _template, decoration: const InputDecoration(labelText: 'Modèle ZPL'), items: const [DropdownMenuItem(value: 'normal', child: Text('Normal (2,25 x 1,25)')), DropdownMenuItem(value: 'small', child: Text('Petit (1,25 x 1,00)')), DropdownMenuItem(value: 'alternative', child: Text('Alternative (2,00 x 1,00)')), DropdownMenuItem(value: 'jewelry', child: Text('Bijoux (2,20 x 0,50)')), DropdownMenuItem(value: 'custom', child: Text('Personnalisé'))], onChanged: (value) => setState(() => _template = value ?? 'normal')), const SizedBox(height: 12),
      if (_template == 'custom') Row(children: [Expanded(child: TextField(controller: _width, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Largeur (mm)'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Hauteur (mm)')))]),
      if (_template == 'custom') const SizedBox(height: 12),
      TextField(controller: _dpi, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Résolution DPI', hintText: '203 ou 300')), const SizedBox(height: 12),
      Text('Rotation ZPL : $_rotation°'), Slider(value: _rotation.toDouble(), min: 0, max: 360, divisions: 8, label: '$_rotation°', onChanged: (value) => setState(() => _rotation = value.round())), const SizedBox(height: 16),
      FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
    ]));
  }
}
