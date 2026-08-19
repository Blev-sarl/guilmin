import 'package:flutter/material.dart';
import '../controllers/reception_controller.dart';
import '../models/reception_type.dart';
import '../services/odoo_client.dart';
import 'operations_page.dart';

class ReceptionTypesPage extends StatefulWidget {
  const ReceptionTypesPage({
    super.key,
    required this.client,
    required this.url,
  });
  final OdooClient client;
  final String url;

  @override
  State<ReceptionTypesPage> createState() => _ReceptionTypesPageState();
}

class _ReceptionTypesPageState extends State<ReceptionTypesPage> {
  late final ReceptionController _controller;
  String _query = '';
  bool _editingVisibility = false;

  @override
  void initState() {
    super.initState();
    _controller = ReceptionController(widget.client, widget.url)
      ..addListener(_refresh);
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
        title: const Text('Opérations'),
        actions: <Widget>[
          IconButton(
            tooltip: _editingVisibility
                ? 'Terminer la personnalisation'
                : 'Modifier les types affichés',
            onPressed: () =>
                setState(() => _editingVisibility = !_editingVisibility),
            icon: Icon(_editingVisibility ? Icons.check : Icons.edit_outlined),
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SearchBar(
              hintText: 'Rechercher un type d’opération',
              leading: const Icon(Icons.search),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          if (_editingVisibility)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _controller.showAllTypes,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Tout afficher'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _controller.hideAllTypes,
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('Tout cacher'),
                    ),
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

    final types = _controller.types
        .where((type) {
          if (!_editingVisibility && _controller.isHidden(type.id)) {
            return false;
          }
          if (_query.isEmpty) return true;
          return type.name.toLowerCase().contains(_query) ||
              type.warehouse.toLowerCase().contains(_query) ||
              type.sequenceCode.toLowerCase().contains(_query);
        })
        .toList(growable: false);

    if (types.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? 'Aucun type d’opération trouvé' : 'Aucun résultat',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        return RefreshIndicator(
          onRefresh: _controller.load,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: _editingVisibility ? 170 : 126,
            ),
            itemCount: types.length,
            itemBuilder: (_, index) {
              final type = types[index];
              return _OperationTypeCard(
                type: type,
                editing: _editingVisibility,
                hidden: _controller.isHidden(type.id),
                onToggleVisibility: () => _controller.toggleVisibility(type.id),
                onTap: _editingVisibility ? null : () => _openOperations(type),
              );
            },
          ),
        );
      },
    );
  }

  void _openOperations(ReceptionType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OperationsPage(client: widget.client, url: widget.url, type: type),
      ),
    );
  }
}

class _OperationTypeCard extends StatelessWidget {
  const _OperationTypeCard({
    required this.type,
    required this.editing,
    required this.hidden,
    required this.onToggleVisibility,
    required this.onTap,
  });
  final ReceptionType type;
  final bool editing;
  final bool hidden;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: hidden ? 0.55 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        type.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Icon(
                            _iconFor(type.code),
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              type.warehouse.isEmpty
                                  ? type.sequenceCode
                                  : type.warehouse,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      if (editing) ...<Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: hidden
                              ? FilledButton.icon(
                                  onPressed: onToggleVisibility,
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Afficher'),
                                )
                              : OutlinedButton.icon(
                                  onPressed: onToggleVisibility,
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                  ),
                                  label: const Text('Cacher'),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${type.operationCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String code) {
    switch (code) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'internal':
        return Icons.swap_horiz;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
