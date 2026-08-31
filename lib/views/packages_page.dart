import 'package:flutter/material.dart';
import '../models/package_option.dart';
import '../services/odoo_client.dart';
import '../services/preferences_service.dart';
import '../services/zpl_printer_service.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.client, required this.url});

  final OdooClient client;
  final String url;

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  late Future<List<PackageOption>> _packages;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _packages = widget.client.getPackages(widget.url, query: _search.text.trim());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _open(PackageOption package) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackageDetailPage(client: widget.client, url: widget.url, package: package)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Colis'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualiser')],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(labelText: 'Rechercher un colis', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () { _search.clear(); _load(); }, icon: const Icon(Icons.clear))),
            ),
          ),
          Expanded(child: FutureBuilder<List<PackageOption>>(
            future: _packages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Impossible de charger les colis\n${snapshot.error}', textAlign: TextAlign.center));
              final packages = snapshot.data ?? const <PackageOption>[];
              if (packages.isEmpty) return const Center(child: Text('Aucun colis trouvé'));
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: packages.length,
                itemBuilder: (_, index) {
                  final package = packages[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFD9E3EF)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      onTap: () => _open(package),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF245D98)),
                      ),
                      title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PackageListInfo(icon: Icons.category_outlined, text: 'Contient ${package.productCount} produit${package.productCount > 1 ? 's' : ''}'),
                            if (package.location.isNotEmpty)
                              _PackageListInfo(icon: Icons.location_on_outlined, text: package.location),
                            if (package.createdAt != null)
                              _PackageListInfo(icon: Icons.calendar_today_outlined, text: 'Colisage : ${PackageDetailPage._formatDate(package.createdAt!)}'),
                            if (package.container.isNotEmpty)
                              _PackageListInfo(icon: Icons.inbox_outlined, text: package.container),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            },
          )),
        ]),
      );
}

class PackageDetailPage extends StatelessWidget {
  const PackageDetailPage({super.key, required this.client, required this.url, required this.package});
  final OdooClient client;
  final String url;
  final PackageOption package;

  Future<void> _print(BuildContext context) async {
    await _printBlev(context);
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[\^~]'), ' ').replaceAll('\\', '/');

  Future<void> _printBlev(BuildContext context) async {
    try {
      final printer = await PreferencesService().loadZplPrinter();
      final ip = (printer['ip'] as String).trim();
      if (ip.isEmpty) throw Exception('Configurez d’abord l’imprimante ZPL');
      final contents = await client.getPackageContents(url, package.id);
      if (contents.isEmpty) {
        throw Exception('Le colis est vide, aucune impression possible');
      }
      final zpl = StringBuffer('''^XA
^CI28
^PW567
^LL856
^LH0,0
^FO495,45
^A0R,40,40
^FD${_safe(package.name)}^FS
^FO475,450
^BY2,3,90
^BCR,90,Y,N,N
^FD${_safe(package.name)}^FS
^FO465,0
^A0R,28,28
^FDDate d'emballage : ${_date(package.createdAt)}^FS
^FO45,15
^GB397,826,2^FS
^FO442,15
^GB2,826,2^FS
^FO365,15
^GB2,826,2^FS
^FO382,55
^A0R,22,22
^FDCode-barres^FS
^FO382,555
^A0R,22,22
^FDQuantité^FS
^FO382,300
^A0R,22,22
^FDProduit^FS
^FO382,685
^A0R,22,22
^FDContenus^FS
''');
      for (final entry in contents.take(7).indexed) {
        final item = entry.$2;
        final name = item['product_id'] is List ? item['product_id'][1].toString() : 'Produit';
        final barcode = (item['_barcode'] ?? '').toString();
        if (entry.$1 > 0) {
          zpl.write('^XA\n^CI28\n^PW567\n^LL856\n^LH0,0\n^FO515,20\n^A0R,40,40\n^FD${_safe(package.name)}^FS\n^FO475,450\n^BY2,3,90\n^BCR,90,Y,N,N\n^FD${_safe(package.name)}^FS\n^FO435,20\n^A0R,28,28\n^FDDate d\'emballage : ${_date(package.createdAt)}^FS\n^FO92,15\n^GB350,826,2^FS\n^FO442,15\n^GB2,826,2^FS\n^FO382,55\n^A0R,22,22\n^FDCode-barres^FS\n^FO382,300\n^A0R,22,22\n^FDProduit^FS\n^FO382,555\n^A0R,22,22\n^FDQuantité^FS\n^FO382,685\n^A0R,22,22\n^FDContenus^FS\n');
        }
        if (barcode.isNotEmpty) {
          zpl.write('^FO120,35\n^BY2,2,75\n^BCR,75,N,N,N\n^FD${_safe(barcode)}^FS\n^FO45,45\n^A0R,20,20\n^FD${_safe(barcode)}^FS\n');
        }
        final words = _safe(name).split(RegExp(r'\s+'));
        var line = StringBuffer();
        var lineIndex = 0;
        void writeLine() {
          if (line.isEmpty || lineIndex >= 5) return;
          final x = 320 - lineIndex * 25;
          zpl.write('^FO$x,300\n^A0R,18,18\n^FD$line^FS\n');
          line = StringBuffer();
          lineIndex++;
        }
        for (final word in words) {
          if (line.isNotEmpty && line.length + word.length + 1 > 32) writeLine();
          if (line.isNotEmpty) line.write(' ');
          line.write(word);
        }
        writeLine();
        zpl.write('^FO275,570\n^A0R,32,32\n^FD${_safe((item['quantity'] ?? 0).toString())}^FS\n^FO235,570\n^A0R,22,22\n^FD${_unitLabel(item)}^FS\n');
        final qrContent = barcode.isEmpty ? package.name : barcode;
        zpl.write('^FO215,610\n^BQR,2,6\n^FDLA,${_safe(qrContent)}^FS\n^FO115,615\n^A0R,19,19\n^FDContenu^FS\n^XZ');
      }
      final service = ZplPrinterService();
      // Supprime les espaces d'indentation avant les commandes ZPL.
      // Ils peuvent être convertis en entités HTML (par ex. &#x20;) par
      // certains outils de transfert et rendre l'étiquette invalide.
      final payload = zpl
          .toString()
          .split('\n')
          .map((line) => line.trimLeft())
          .join('\n')
          .replaceAll(RegExp(r'&#x[0-9A-Fa-f]+;'), '');
      await service.sendZpl(zpl: payload, ip: ip, port: printer['port'] as int);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impression colis ZPL Blev envoyée')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impression ZPL impossible : $error')));
    }
  }

  String _unitLabel(Map<String, dynamic> item) {
    final unit = (item['_uom_name'] ?? '').toString().trim();
    return unit.isEmpty ? 'Unite(s)' : unit;
  }

  String _date(DateTime? value) { final date = value ?? DateTime.now(); return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'; }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(package.name)),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 5,
        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => _print(context),
            icon: const Icon(Icons.print_outlined, size: 25),
            label: const Text('Imprimer code-barre du colis avec contenu', textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
    body: Column(children: [
      Card(
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD9E3EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE8F1FA), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF245D98))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Informations du colis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(package.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ])),
            ]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
            _PackageInfoRow(icon: Icons.location_on_outlined, label: 'Emplacement', value: package.location.isEmpty ? 'Non renseigné' : package.location),
            const SizedBox(height: 10),
            _PackageInfoRow(icon: Icons.calendar_today_outlined, label: 'Date de colisage', value: package.createdAt == null ? 'Non renseignée' : _formatDate(package.createdAt!)),
          ]),
        ),
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: client.getPackageContents(url, package.id), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Impossible de charger le contenu\n${snapshot.error}', textAlign: TextAlign.center));
      final items = snapshot.data ?? const <Map<String, dynamic>>[];
      if (items.isEmpty) return const Center(child: Text('Ce colis est vide'));
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 92),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(children: [
              Text('Contenu du colis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${items.length} produit${items.length > 1 ? 's' : ''}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          ...items.map((item) {
            final product = item['product_id'] is List ? item['product_id'][1].toString() : 'Produit';
            final quantity = item['quantity'] ?? 0;
            final unit = (item['_uom_name'] ?? (item['product_uom_id'] is List ? item['product_uom_id'][1] : '')).toString();
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFD9E3EF))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: const CircleAvatar(backgroundColor: Color(0xFFE8F1FA), child: Icon(Icons.inventory_2_outlined, color: Color(0xFF245D98), size: 20)),
                title: Text(product, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$quantity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), if (unit.isNotEmpty) Text(unit, style: Theme.of(context).textTheme.bodySmall)]),
              ),
            );
          }),
        ],
      );
    })),
    ]),
  );

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PackageListInfo extends StatelessWidget {
  const _PackageListInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF60758A)),
          const SizedBox(width: 5),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _PackageInfoRow extends StatelessWidget {
  const _PackageInfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text('$label : $value', maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]);
}
