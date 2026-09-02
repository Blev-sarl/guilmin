import 'dart:async';

import 'package:flutter/material.dart';
import '../controllers/operations_controller.dart';
import '../models/reception_type.dart';
import '../models/stock_operation.dart';
import '../services/odoo_client.dart';
import 'operation_detail_page.dart';
import 'camera_scanner_page.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({
    super.key,
    required this.client,
    required this.url,
    required this.type,
    this.draftOnly = false,
  });
  final OdooClient client;
  final String url;
  final ReceptionType type;
  final bool draftOnly;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  late final OperationsController _controller;
  String _query = '';
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Set<String> _stateFilter = <String>{'assigned'};
  String _packageFilter = 'all';

  @override
  void initState() {
    super.initState();
    _controller = OperationsController(
      widget.client,
      widget.url,
      widget.type.id,
    )..addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _scanTransferQrCode() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const CameraScannerPage(
          title: 'Scanner un transfert',
          instruction: 'Placez le QR code du transfert dans le cadre',
        ),
      ),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    final query = value.trim();
    _searchController.text = query;
    setState(() => _query = query.toLowerCase());
  }

  Future<void> _createTransfer() async {
    final locationInput = TextEditingController();
    List<Map<String, dynamic>> suggestions = <Map<String, dynamic>>[];
    bool searchingLocations = false;
    try {
      suggestions = await widget.client.searchLocations(widget.url, '');
    } catch (_) {
      // La recherche saisie affichera l’erreur éventuelle via Odoo.
    }
    if (!mounted) {
      locationInput.dispose();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Emplacement d’origine'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          TextField(
            controller: locationInput,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Rechercher ou saisir le code', prefixIcon: Icon(Icons.location_on_outlined)),
            onChanged: (value) async {
              if (value.trim().length < 2) { setDialogState(() => suggestions = <Map<String, dynamic>>[]); return; }
              setDialogState(() => searchingLocations = true);
              try {
                final found = await widget.client.searchLocations(widget.url, value.trim());
                if (context.mounted) setDialogState(() => suggestions = found);
              } finally {
                if (context.mounted) setDialogState(() => searchingLocations = false);
              }
            },
          ),
          if (searchingLocations) const LinearProgressIndicator(),
          if (suggestions.isNotEmpty) SizedBox(height: 180, child: ListView.builder(itemCount: suggestions.length, itemBuilder: (_, index) {
            final item = suggestions[index];
            return ListTile(dense: true, leading: const Icon(Icons.location_on_outlined), title: Text('${item['name'] ?? ''}'), subtitle: Text('${item['barcode'] ?? 'Sans code-barres'}'), onTap: () => Navigator.pop(context, 'id:${item['id']}'));
          })),
        ])),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, '__scan__'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, locationInput.text),
            child: const Text('Rechercher'),
          ),
        ],
      )),
    );
    if (!mounted) {
      locationInput.dispose();
      return;
    }
    final navigator = Navigator.of(context);
    final barcode = choice == '__scan__'
        ? await navigator.push<String>(MaterialPageRoute<String>(builder: (_) => const CameraScannerPage(
            title: 'Scanner l’emplacement d’origine',
            instruction: 'Scannez le QR code de l’emplacement source',
          )))
        : choice;
    locationInput.dispose();
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    final selected = barcode.trim();
    final locationId = selected.startsWith('id:')
        ? int.tryParse(selected.substring(3))
        : await widget.client.findLocationByBarcode(widget.url, selected);
    if (!mounted) return;
    if (locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emplacement d’origine introuvable')));
      return;
    }
    final input = TextEditingController();
    final origin = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Créer un transfert'),
      content: TextField(controller: input, autofocus: true, decoration: const InputDecoration(labelText: 'Référence ou origine (facultatif)')),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, input.text), child: const Text('Créer'))],
    ));
    input.dispose();
    if (!mounted || origin == null) return;
    try {
      final transferId = await widget.client.createTransfer(url: widget.url, pickingTypeId: widget.type.id, locationId: locationId, origin: origin);
      await _controller.load();
      if (!mounted) return;
      final created = _controller.operations.where((item) => item.id == transferId).firstOrNull;
      if (created != null) {
        await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => OperationDetailPage(client: widget.client, url: widget.url, operation: created)));
        if (mounted) await _controller.load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfert créé')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draftOnly ? '${widget.type.name} - Brouillons' : widget.type.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(tooltip: 'Créer un transfert', onPressed: _createTransfer, icon: const Icon(Icons.add_box_outlined)),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              trailing: <Widget>[
                IconButton(
                  tooltip: 'Scanner le QR code du transfert',
                  onPressed: _scanTransferQrCode,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
              hintText: 'Type d’opération, transfert ou fournisseur',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    setState(() => _query = value.trim().toLowerCase());
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.start,
                children: <Widget>[
                FilterChip(
                  label: const Text('Prêt'),
                  selectedColor: const Color(0xFF8FD19A),
                  checkmarkColor: const Color(0xFF236B35),
                  labelStyle: TextStyle(
                    color: _stateFilter.contains('assigned')
                        ? const Color(0xFF123F20)
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                  selected: _stateFilter.contains('assigned'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('assigned'); } else { _stateFilter.remove('assigned'); }
                  }),
                ),
                FilterChip(
                  label: const Text('Brouillon'),
                  selectedColor: const Color(0xFFB5C7DC),
                  checkmarkColor: const Color(0xFF365A7D),
                  labelStyle: TextStyle(
                    color: _stateFilter.contains('draft')
                        ? const Color(0xFF243F5C)
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                  selected: _stateFilter.contains('draft'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('draft'); } else { _stateFilter.remove('draft'); }
                  }),
                ),
                FilterChip(
                  label: const Text('En attente'),
                  selectedColor: const Color(0xFFF5B85F),
                  checkmarkColor: const Color(0xFF9A5700),
                  labelStyle: TextStyle(
                    color: _stateFilter.contains('waiting')
                        ? const Color(0xFF643800)
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                  selected: _stateFilter.contains('waiting'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('waiting'); } else { _stateFilter.remove('waiting'); }
                  }),
                ),
                FilterChip(
                  label: const Text('Terminé'),
                  selectedColor: const Color(0xFF8DBBE8),
                  checkmarkColor: const Color(0xFF245D98),
                  labelStyle: TextStyle(
                    color: _stateFilter.contains('done')
                        ? const Color(0xFF173F6A)
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                  selected: _stateFilter.contains('done'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('done'); } else { _stateFilter.remove('done'); }
                  }),
                ),
                FilterChip(
                  label: const Text('Colis oui'),
                  selectedColor: const Color(0xFFB8E5C1),
                  checkmarkColor: const Color(0xFF216B32),
                  selected: _packageFilter == 'yes',
                  onSelected: (selected) => setState(() => _packageFilter = selected ? 'yes' : 'all'),
                ),
                FilterChip(
                  label: const Text('Colis non'),
                  selectedColor: const Color(0xFFFFC7C2),
                  checkmarkColor: const Color(0xFF9B2C25),
                  selected: _packageFilter == 'no',
                  onSelected: (selected) => setState(() => _packageFilter = selected ? 'no' : 'all'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_controller.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final operations = _controller.operations
        .where((operation) {
          final stateMatches = widget.draftOnly
              ? operation.state == 'draft'
              : operation.state == 'confirmed'
              ? _stateFilter.contains('waiting')
              : _stateFilter.contains(operation.state);
          if (!stateMatches) return false;
          if (_packageFilter == 'yes' && !operation.hasPackages) return false;
          if (_packageFilter == 'no' && operation.hasPackages) return false;
          if (_query.isEmpty) return true;
          return operation.reference.toLowerCase().contains(_query) ||
              operation.origin.toLowerCase().contains(_query) ||
              operation.partner.toLowerCase().contains(_query) ||
              operation.supplierReference.toLowerCase().contains(_query);
        })
        .toList(growable: false);

    if (operations.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? 'Aucune opération en attente' : 'Aucun résultat',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        cacheExtent: 600,
        addAutomaticKeepAlives: false,
        addSemanticIndexes: false,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: operations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, index) {
          final operation = operations[index];
          return _OperationCard(
            operation: operation,
            onTap: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => OperationDetailPage(
                    client: widget.client,
                    url: widget.url,
                    operation: operation,
                  ),
                ),
              );
              if (mounted) await _controller.load();
            },
          );
        },
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.operation, required this.onTap});
  final StockOperation operation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = operation.state == 'assigned';
    return Card(
      elevation: 0,
      color: ready ? const Color(0xFFF1F8F2) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: ready ? const Color(0xFF8DC497) : const Color(0xFFD9E3EF),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      operation.reference,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StateChip(state: operation.state),
                ],
              ),
              if (operation.origin.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _Info(
                  icon: Icons.description_outlined,
                  label: 'Document d’origine',
                  text: operation.origin,
                ),
              ],
              if (operation.supplierReference.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _Info(
                  icon: Icons.receipt_long_outlined,
                  label: 'Référence fournisseur',
                  text: operation.supplierReference,
                ),
              ],
              if (operation.partner.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _Info(
                  icon: Icons.business_outlined,
                  label: 'Fournisseur',
                  text: operation.partner,
                ),
              ],
              if (operation.scheduledDate != null) ...<Widget>[
                const SizedBox(height: 6),
                _Info(
                  icon: Icons.schedule,
                  label: 'Date prévue',
                  text: _formatDate(operation.scheduledDate!),
                ),
              ],
              const SizedBox(height: 6),
              _PackageInfo(hasPackages: operation.hasPackages),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.text});
  final IconData icon;
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '$label : $text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _PackageInfo extends StatelessWidget {
  const _PackageInfo({required this.hasPackages});
  final bool hasPackages;

  @override
  Widget build(BuildContext context) {
    final color = hasPackages ? const Color(0xFF247A38) : const Color(0xFFB33A32);
    return Row(children: <Widget>[
      Icon(Icons.inventory_2_outlined, size: 17, color: color),
      const SizedBox(width: 8),
      Text('Colis : ${hasPackages ? 'Oui' : 'Non'}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'draft': 'Brouillon',
      'waiting': 'En attente',
      'confirmed': 'En attente',
      'assigned': 'Prêt',
      'done': 'Terminé',
      'cancel': 'Annulé',
    };
    final ready = state == 'assigned';
    final color = ready ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        labels[state] ?? state,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
