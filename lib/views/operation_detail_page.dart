import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/operation_detail_controller.dart';
import '../models/operation_line.dart';
import '../models/package_option.dart';
import '../models/stock_operation.dart';
import '../services/odoo_client.dart';
import '../services/barcode_pdf_service.dart';
import 'product_quantity_page.dart';
import 'widgets/package_picker_dialog.dart';

enum _PrintChoice {
  operations(
    'Imprimer les opérations de transfert',
    'stock.action_report_picking',
    Icons.assignment_outlined,
    'operations_transfert',
  ),
  delivery(
    'Imprimer le bon de livraison',
    'stock.action_report_delivery',
    Icons.local_shipping_outlined,
    'bon_livraison',
  ),
  barcodes(
    'Imprimer les code-barres',
    'stock.action_report_picking',
    Icons.qr_code_2,
    'codes_barres',
  ),
  packages(
    'Imprimer des colis',
    'stock.action_report_picking',
    Icons.inventory_2_outlined,
    'colis',
  );

  const _PrintChoice(this.label, this.reportName, this.icon, this.filePrefix);
  final String label;
  final String reportName;
  final IconData icon;
  final String filePrefix;
}

enum _BarcodeLabelFormat {
  dymo('Dymo', 'product.report_product_template_label_dymo'),
  twoBySeven('2 x 7 avec le prix', 'product.report_product_template_label_2x7'),
  fourBySeven('4 x 7 avec le prix', 'product.report_product_template_label_4x7'),
  fourByTwelve('4 x 12', 'product.report_product_template_label_4x12'),
  fourByTwelveNoPrice(
    '4 x 12 sans le prix',
    'product.report_product_template_label_4x12_noprice',
  );

  const _BarcodeLabelFormat(this.label, this.reportName);
  final String label;
  final String reportName;
}

class OperationDetailPage extends StatefulWidget {
  const OperationDetailPage({
    super.key,
    required this.client,
    required this.url,
    required this.operation,
  });
  final OdooClient client;
  final String url;
  final StockOperation operation;
  @override
  State<OperationDetailPage> createState() => _OperationDetailPageState();
}

class _OperationDetailPageState extends State<OperationDetailPage>
    with SingleTickerProviderStateMixin {
  late final OperationDetailController _controller;
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  final TextEditingController _manualScanController = TextEditingController();
  final FocusNode _manualScanFocusNode = FocusNode();
  late final AnimationController _completionBlinkController;
  bool _cameraVisible = false;
  bool _manualScanVisible = false;
  bool _showTouchKeyboard = false;
  bool _scanBusy = false;
  bool _printing = false;
  @override
  void initState() {
    super.initState();
    _completionBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.55,
      upperBound: 1,
    )..repeat(reverse: true);
    _controller = OperationDetailController(
      widget.client,
      widget.url,
      widget.operation.id,
    )..addListener(_refresh);
    _controller.load();
    _loadPdaKeyboardPreference();
    _restoreLastScanMode();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _completionBlinkController.dispose();
    _cameraController.dispose();
    _manualScanController.dispose();
    _manualScanFocusNode.dispose();
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.operation.reference),
        actions: <Widget>[
          IconButton(
            tooltip: 'Imprimer',
            onPressed: _printing ? null : _showPrintMenu,
            icon: const Icon(Icons.print_outlined),
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
          if (!_cameraVisible && !_manualScanVisible)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _controller.saving ? null : _toggleCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('SCAN CAMÉRA'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 38,
                      color: Theme.of(context).dividerColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _controller.saving
                            ? null
                            : _toggleManualScan,
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('SCAN PDA'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_cameraVisible) _buildInlineScanner(),
          if (_manualScanVisible) _buildManualScanner(),
          if (_allProductsCompleted) _buildCompletionBanner(),
          if (widget.operation.origin.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Text('Document d’origine : ${widget.operation.origin}'),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.saving ? null : _toggleManualScan,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un produit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.saving ? null : _globalPackage,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Mettre en colis'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _controller.saving ? null : _validate,
                  icon: const Icon(Icons.check),
                  label: const Text('Valider'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrintMenu() async {
    final hasPackages = _controller.lines.any(
      (line) => line.destinationPackage.trim().isNotEmpty,
    );
    final choice = await showModalBottomSheet<_PrintChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(title: Text('Impression'), leading: Icon(Icons.print)),
            for (final item in _PrintChoice.values)
              ListTile(
                enabled: item != _PrintChoice.packages || hasPackages,
                leading: Icon(
                  item.icon,
                  color: item == _PrintChoice.packages && !hasPackages
                      ? Theme.of(context).disabledColor
                      : null,
                ),
                title: Text(item.label),
                onTap: item == _PrintChoice.packages && !hasPackages
                    ? null
                    : () => Navigator.pop(context, item),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Retour'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    _BarcodeLabelFormat? barcodeFormat;
    if (choice == _PrintChoice.barcodes) {
      barcodeFormat = await _showBarcodeFormatDialog();
      if (barcodeFormat == null || !mounted) return;
    }
    final selectedBarcodeFormat = barcodeFormat;
    setState(() => _printing = true);
    try {
      final productIds = _controller.lines
          .map((line) => line.productId)
          .whereType<int>()
          .toSet();
      final packageIds = _controller.lines
          .map((line) => line.destinationPackageId)
          .whereType<int>()
          .toSet()
          .toList();
      final barcodeTemplateIds = choice == _PrintChoice.barcodes
          ? await widget.client.getProductTemplateIds(widget.url, productIds)
          : const <int>[];
      debugPrint('IDs modèles produits envoyés à Odoo : $barcodeTemplateIds');
      if (choice == _PrintChoice.barcodes && barcodeTemplateIds.isEmpty) {
        throw Exception('Aucun modèle produit trouvé pour les codes-barres');
      }
      if (choice == _PrintChoice.barcodes) {
        final codes = await widget.client.getProductScanCodes(widget.url, productIds);
        final labels = <BarcodePdfItem>[];
        for (final line in _controller.lines) {
          final productCodes = line.productId == null ? null : codes[line.productId];
          if (productCodes == null || productCodes.isEmpty) continue;
          final quantity = line.expectedQuantity.ceil().clamp(1, 999);
          for (var index = 0; index < quantity; index++) {
            labels.add(BarcodePdfItem(code: productCodes.first, name: line.productName));
          }
        }
        if (labels.isEmpty) throw Exception('Aucun code-barres produit trouvé');
        final fourColumns = selectedBarcodeFormat == _BarcodeLabelFormat.fourBySeven ||
            selectedBarcodeFormat == _BarcodeLabelFormat.fourByTwelve ||
            selectedBarcodeFormat == _BarcodeLabelFormat.fourByTwelveNoPrice;
        final rows = selectedBarcodeFormat == _BarcodeLabelFormat.fourByTwelve ||
                selectedBarcodeFormat == _BarcodeLabelFormat.fourByTwelveNoPrice
            ? 12
            : selectedBarcodeFormat == _BarcodeLabelFormat.dymo ? 1 : 7;
        final bytes = await BarcodePdfService().build(
          items: labels, columns: fourColumns ? 4 : 2, rows: rows,
        );
        await Printing.layoutPdf(
          name: choice.label,
          onLayout: (_) async => Uint8List.fromList(bytes),
        );
        return;
      }
      final labelAction = choice == _PrintChoice.barcodes
          ? await widget.client.prepareProductLabelReport(
              url: widget.url,
              productIds: productIds.toList(growable: false),
              layout: _odoo19Layout(selectedBarcodeFormat!),
            )
          : null;
      final barcodeReportName = labelAction == null
          ? barcodeFormat?.reportName
          : (labelAction['report_name']?.toString() ??
              selectedBarcodeFormat?.reportName);
      final report = await widget.client.downloadReport(
        url: widget.url,
        reportName: choice == _PrintChoice.barcodes
            ? (barcodeReportName ??
                (throw Exception('Format de code-barres non sélectionné')))
            : choice == _PrintChoice.packages
            ? 'stock.action_report_package_barcode'
            : choice.reportName,
        recordIds: choice == _PrintChoice.barcodes
            ? const <int>[]
            : choice == _PrintChoice.packages
            ? packageIds
            : <int>[widget.operation.id],
        fileName: '${choice.filePrefix}_${widget.operation.reference}',
        data: labelAction != null && labelAction['data'] is Map
            ? Map<String, dynamic>.from(labelAction['data'] as Map)
            : null,
      );
      await Printing.layoutPdf(
        name: choice.label,
        onLayout: (_) => report.readAsBytes(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impression impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _odoo19Layout(_BarcodeLabelFormat format) => switch (format) {
    _BarcodeLabelFormat.dymo => 'dymo',
    _BarcodeLabelFormat.twoBySeven => '2x7xprice',
    _BarcodeLabelFormat.fourBySeven => '4x7xprice',
    _BarcodeLabelFormat.fourByTwelve => '4x12',
    _BarcodeLabelFormat.fourByTwelveNoPrice => '4x12xprice',
  };

  Future<_BarcodeLabelFormat?> _showBarcodeFormatDialog() {
    var selected = _BarcodeLabelFormat.twoBySeven;
    return showDialog<_BarcodeLabelFormat>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir le modèle d’étiquettes'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Quantité à imprimer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Quantités de l’opération'),
                const SizedBox(height: 16),
                const Text(
                  'Format',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioGroup<_BarcodeLabelFormat>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selected = value);
                  },
                  child: Column(
                    children: _BarcodeLabelFormat.values
                        .map(
                          (format) => RadioListTile<_BarcodeLabelFormat>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(format.label),
                            value: format,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ignorer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Imprimer'),
            ),
          ],
        ),
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
    if (_controller.lines.isEmpty) {
      return const Center(child: Text('Aucun produit dans cette opération'));
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.separated(
        itemCount: _controller.lines.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final line = _controller.lines[index];
          return _ProductLineCard(
            line: line,
            highlighted: _controller.lastScannedLineId == line.id,
            enabled: !_controller.saving,
            onSetQuantity: (quantity) =>
                _controller.setQuantity(line.id, quantity),
            onEdit: () => _editQuantity(line),
          );
        },
      ),
    );
  }

  bool get _allProductsCompleted =>
      _controller.lines.isNotEmpty &&
      _controller.lines.every(
        (line) => line.doneQuantity >= line.expectedQuantity,
      );

  Widget _buildCompletionBanner() {
    return AnimatedBuilder(
      animation: _completionBlinkController,
      builder: (context, child) => Opacity(
        opacity: _completionBlinkController.value,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.green.shade700,
        child: Row(
          children: <Widget>[
            const Icon(Icons.check_circle, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tous les produits du transfert ont été scannés. '
                'Validez pour confirmer le transfert.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleCamera() async {
    if (_cameraVisible) {
      await _cameraController.stop();
      if (mounted) setState(() => _cameraVisible = false);
      return;
    }
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!supported) {
      _message('La caméra n’est pas disponible sur cette plateforme.');
      return;
    }
    setState(() => _cameraVisible = true);
    await _saveScanMode('camera');
    try {
      await _cameraController.start();
    } catch (error) {
      if (mounted) {
        setState(() => _cameraVisible = false);
        _message('Impossible d’ouvrir la caméra. Vérifiez son autorisation.');
      }
    }
  }

  Widget _buildInlineScanner() {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _cameraController,
            onDetect: _onCameraDetect,
            errorBuilder: (context, error) =>
                Center(child: Text('Erreur caméra : ${error.errorCode.name}')),
          ),
          Center(
            child: Container(
              width: 270,
              height: 145,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF65A56F), width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Flash',
                  onPressed: _cameraController.toggleTorch,
                  icon: const Icon(Icons.flash_on),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Fermer',
                  onPressed: _toggleCamera,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualScanner() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: ValueKey<bool>(_showTouchKeyboard),
                    controller: _manualScanController,
                    focusNode: _manualScanFocusNode,
                    autofocus: true,
                    keyboardType: _showTouchKeyboard
                        ? TextInputType.text
                        : TextInputType.none,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      labelText: 'Code-barres ou référence interne',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                    onSubmitted: (_) => _submitManualScan(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Valider le scan PDA',
                  onPressed: _scanBusy ? null : _submitManualScan,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: _toggleManualScan,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                tooltip: _showTouchKeyboard
                    ? 'Désactiver le clavier tactile'
                    : 'Activer le clavier tactile',
                onPressed: _toggleTouchKeyboard,
                icon: Icon(
                  _showTouchKeyboard
                      ? Icons.keyboard
                      : Icons.keyboard_hide_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleManualScan() {
    final opening = !_manualScanVisible;
    setState(() => _manualScanVisible = opening);
    if (opening) _saveScanMode('pda');
    if (!_manualScanVisible) _manualScanController.clear();
  }

  Future<void> _saveScanMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('last_scan_mode', mode);
  }

  Future<void> _restoreLastScanMode() async {
    final preferences = await SharedPreferences.getInstance();
    final mode = preferences.getString('last_scan_mode');
    if (!mounted) return;
    if (mode == 'camera') {
      await _toggleCamera();
    } else if (mode == 'pda') {
      setState(() => _manualScanVisible = true);
    }
  }

  Future<void> _loadPdaKeyboardPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showTouchKeyboard =
          preferences.getBool('pda_show_touch_keyboard') ?? false;
    });
  }

  Future<void> _toggleTouchKeyboard() async {
    final enabled = !_showTouchKeyboard;
    setState(() => _showTouchKeyboard = enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('pda_show_touch_keyboard', enabled);
    if (!enabled) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    if (mounted) {
      _manualScanFocusNode.requestFocus();
      _message(
        enabled
            ? 'Clavier tactile activé et réglage sauvegardé.'
            : 'Clavier tactile désactivé et réglage sauvegardé.',
      );
    }
  }

  Future<void> _submitManualScan() async {
    final value = _manualScanController.text.trim();
    if (value.isEmpty) return;
    await _processScannedValue(value);
    if (mounted) {
      _manualScanController.clear();
      _manualScanFocusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _manualScanVisible) {
          _manualScanFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _onCameraDetect(BarcodeCapture capture) async {
    if (_scanBusy) return;
    String? value;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue?.isNotEmpty == true) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null) return;
    await _processScannedValue(value);
  }

  Future<void> _processScannedValue(String value) async {
    if (_scanBusy) return;
    _scanBusy = true;
    try {
      final line = await _controller.scan(value);
      if (mounted && line != null) {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.mediumImpact();
        if (mounted) _message('${line.productName} : +1');
      }
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _scanBusy = false;
    }
  }

  Future<void> _editQuantity(OperationLine line) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ProductQuantityPage(
          operation: widget.operation,
          line: line,
          onConfirm: (quantity) async {
            await _controller.setQuantity(line.id, quantity);
            if (_controller.error != null) {
              throw Exception(_controller.error);
            }
          },
          loadPackages: (query) => _controller.getPackages(query: query),
          createPackage: _controller.createPackage,
          onPackage: (package, source) =>
              _controller.assignPackage(line, package, source: source),
        ),
      ),
    );
    if (result == 'package' && mounted) {
      OperationLine? updated;
      for (final item in _controller.lines) {
        if (item.id == line.id) {
          updated = item;
          break;
        }
      }
      final packageName = updated?.destinationPackage.isNotEmpty == true
          ? updated!.destinationPackage
          : updated?.sourcePackage ?? '';
      _message(
        packageName.isEmpty
            ? 'Affectation du colis mise à jour.'
            : 'Article affecté au colis $packageName.',
      );
    }
  }

  Future<void> _putInPack() async {
    try {
      final packageName = await _controller.putInPack();
      if (mounted) {
        _message(
          'Les quantités traitées ont été mises dans le colis $packageName.',
        );
      }
    } catch (exception) {
      if (mounted) {
        _message(exception.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _globalPackage() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Créer un nouveau colis'),
              subtitle: const Text(
                'Même action que « Mettre en colis » dans Odoo',
              ),
              onTap: () => Navigator.of(sheetContext).pop('create'),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Sélectionner un colis existant'),
              subtitle: const Text(
                'Affecter le colis à toutes les quantités traitées',
              ),
              onTap: () => Navigator.of(sheetContext).pop('select'),
            ),
          ],
        ),
      ),
    );
    if (action == 'create') return _putInPack();
    if (action != 'select' || !mounted) return;
    try {
      final package = await showDialog<PackageOption>(
        context: context,
        builder: (_) => PackagePickerDialog(
          loadPackages: (query) => _controller.getPackages(query: query),
          allowNone: false,
        ),
      );
      if (package != null) {
        await _controller.assignGlobalPackage(package);
        if (mounted) {
          _message('Colis ${package.name} affecté à toute l’opération.');
        }
      }
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _validate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Valider l’opération ?'),
        content: Text(
          'Confirmer la validation de ${widget.operation.reference} dans Odoo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _controller.validate();
      if (!mounted) return;
      if (result is Map) {
        final model = result['res_model']?.toString();
        bool createBackorder = true;
        if (model == 'stock.backorder.confirmation') {
          final choice = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Créer un reliquat ?'),
              content: const Text(
                'Certaines quantités ne sont pas terminées. Voulez-vous créer un reliquat pour les recevoir plus tard ?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Sans reliquat'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Créer un reliquat'),
                ),
              ],
            ),
          );
          if (choice == null || !mounted) return;
          createBackorder = choice;
        }
        await _controller.confirmValidationAction(
          result,
          createBackorder: createBackorder,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (exception) {
      if (mounted) {
        _message(exception.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}

class _ProductLineCard extends StatelessWidget {
  const _ProductLineCard({
    required this.line,
    required this.highlighted,
    required this.enabled,
    required this.onSetQuantity,
    required this.onEdit,
  });
  final OperationLine line;
  final bool highlighted;
  final bool enabled;
  final ValueChanged<double> onSetQuantity;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final reference =
        RegExp(r'^\[([^]]+)\]').firstMatch(line.productName)?.group(1) ?? '';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE5F4E8) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: highlighted ? const Color(0xFF65A56F) : Colors.transparent,
            width: 5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (reference.isNotEmpty)
                      Text(
                        reference,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    Text(
                      line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (line.description.isNotEmpty &&
                        line.description != line.productName) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        line.description,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (line.destination.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 7),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.login, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            line.destination,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Modifier',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (line.destinationPackage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                Icon(
                  Icons.inventory_2_outlined,
                  size: 17,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Colis : ${line.destinationPackage}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text(
                _quantity(line.doneQuantity),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / ${_quantity(line.expectedQuantity)} ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                line.unit,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: enabled && line.doneQuantity > 0
                      ? () => onSetQuantity(0)
                      : null,
                  child: const Text('0'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: enabled && line.doneQuantity > 0
                      ? () => onSetQuantity(line.doneQuantity - 1)
                      : null,
                  child: const Text('-1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed:
                      enabled && line.doneQuantity < line.expectedQuantity
                      ? () => onSetQuantity(line.doneQuantity + 1)
                      : null,
                  child: const Text('+1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed:
                      enabled && line.doneQuantity < line.expectedQuantity
                      ? () => onSetQuantity(line.expectedQuantity)
                      : null,
                  child: Text(_quantity(line.expectedQuantity)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
