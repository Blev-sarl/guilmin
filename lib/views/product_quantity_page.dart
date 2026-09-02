import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/operation_line.dart';
import '../models/package_option.dart';
import '../models/stock_operation.dart';
import 'widgets/package_picker_dialog.dart';

class ProductQuantityPage extends StatefulWidget {
  const ProductQuantityPage({
    super.key,
    required this.operation,
    required this.line,
    required this.onConfirm,
    this.draft = false,
    required this.loadPackages,
    required this.onPackage,
    required this.createPackage,
  });
  final StockOperation operation;
  final OperationLine line;
  final Future<void> Function(double) onConfirm;
  final bool draft;
  final Future<List<PackageOption>> Function(String query) loadPackages;
  final Future<void> Function(PackageOption? package, bool source) onPackage;
  final Future<PackageOption> Function(String name) createPackage;
  @override
  State<ProductQuantityPage> createState() => _ProductQuantityPageState();
}

class _ProductQuantityPageState extends State<ProductQuantityPage> {
  late double quantity;
  late final TextEditingController input;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    quantity = widget.draft ? widget.line.expectedQuantity : widget.line.doneQuantity;
    input = TextEditingController(text: format(quantity));
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void setQuantity(double value) {
    quantity = widget.draft
        ? value.clamp(0, 999999).toDouble()
        : value.clamp(0, widget.line.expectedQuantity).toDouble();
    input.text = format(quantity);
    input.selection = TextSelection.collapsed(offset: input.text.length);
    setState(() {});
  }

  Future<void> confirm() async {
    quantity = double.tryParse(input.text.replaceFirst(',', '.')) ?? quantity;
    quantity = widget.draft
        ? quantity.clamp(0, 999999).toDouble()
        : quantity.clamp(0, widget.line.expectedQuantity).toDouble();
    setState(() => saving = true);
    try {
      await widget.onConfirm(quantity);
      if (mounted) Navigator.of(context).pop('quantity');
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code =
        RegExp(r'^\[([^]]+)\]').firstMatch(widget.line.productName)?.group(1) ??
        '';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.operation.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.operation.partner.isNotEmpty)
              Text(
                widget.operation.partner,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.sell_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  code.isEmpty ? widget.line.productName : code,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.line.productName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.line.description.isNotEmpty &&
              widget.line.description != widget.line.productName)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.line.description),
            ),
          const SizedBox(height: 4),
          Text(
            'Pas de code-barres',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextField(
                  controller: input,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    labelText: widget.draft ? 'Quantité demandée' : 'Quantité traitée',
                  ),
                  onChanged: (value) => quantity =
                      double.tryParse(value.replaceFirst(',', '.')) ?? quantity,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Unité'),
                  child: Text(
                    widget.line.unit,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: saving ? null : () => setQuantity(0),
                  child: const Text('0'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: saving ? null : () => setQuantity(quantity - 1),
                  child: const Text('-1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: saving ? null : () => setQuantity(quantity + 1),
                  child: const Text('+1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () => setQuantity(widget.line.expectedQuantity),
                  child: Text(format(widget.line.expectedQuantity)),
                ),
              ),
            ],
          ),
          if (!widget.draft) ...<Widget>[
          const SizedBox(height: 24),
          _Field(
            icon: Icons.location_on_outlined,
            label: 'Emplacement de destination',
            value: widget.line.destination,
          ),
          const SizedBox(height: 16),
          _Field(
            icon: Icons.inventory_2_outlined,
            label: 'Colis d’origine',
            value: widget.line.sourcePackage,
            onTap: saving ? null : () => selectPackage(source: true),
          ),
          const SizedBox(height: 16),
          _Field(
            icon: Icons.inventory_2_outlined,
            label: 'Colis de destination',
            value: widget.line.destinationPackage,
            onTap: saving ? null : () => selectPackage(source: false),
          ),
          const SizedBox(height: 16),
          _Field(
            icon: Icons.inventory_2_outlined,
            label: 'Colis du conteneur de destination',
            value: widget.line.destinationContainer,
          ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Ignorer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : confirm,
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Future<void> selectPackage({required bool source}) async {
    final selected = await showDialog<PackageOption>(
      context: context,
      builder: (_) => PackagePickerDialog(
        loadPackages: widget.loadPackages,
        createPackage: source ? widget.createPackage : null,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.onPackage(selected.id == -1 ? null : selected, source);
      if (mounted) Navigator.of(context).pop('package');
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            suffixIcon: onTap == null
                ? null
                : const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
  );
}
