import 'package:flutter/material.dart';
import '../controllers/operations_controller.dart';
import '../models/reception_type.dart';
import '../models/stock_operation.dart';
import '../services/odoo_client.dart';
import 'operation_detail_page.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({
    super.key,
    required this.client,
    required this.url,
    required this.type,
  });
  final OdooClient client;
  final String url;
  final ReceptionType type;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  late final OperationsController _controller;
  String _query = '';
  final Set<String> _stateFilter = <String>{'assigned'};

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

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Référence, fournisseur ou document d’origine (PO…)',
              leading: const Icon(Icons.search),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                FilterChip(
                  label: const Text('Prêt'),
                  selected: _stateFilter.contains('assigned'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('assigned'); } else { _stateFilter.remove('assigned'); }
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Brouillon'),
                  selected: _stateFilter.contains('draft'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('draft'); } else { _stateFilter.remove('draft'); }
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('En attente'),
                  selected: _stateFilter.contains('waiting'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('waiting'); } else { _stateFilter.remove('waiting'); }
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Terminé'),
                  selected: _stateFilter.contains('done'),
                  onSelected: (selected) => setState(() {
                    if (selected) { _stateFilter.add('done'); } else { _stateFilter.remove('done'); }
                  }),
                ),
                ],
              ),
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
          final stateMatches = operation.state == 'confirmed'
              ? _stateFilter.contains('waiting')
              : _stateFilter.contains(operation.state);
          if (!stateMatches) return false;
          if (_query.isEmpty) return true;
          return operation.reference.toLowerCase().contains(_query) ||
              operation.origin.toLowerCase().contains(_query) ||
              operation.partner.toLowerCase().contains(_query);
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
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      label: Text(
        labels[state] ?? state,
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
      ),
    );
  }
}
