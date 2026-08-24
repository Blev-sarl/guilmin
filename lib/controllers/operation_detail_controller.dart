import 'package:flutter/foundation.dart';
import '../models/operation_line.dart';
import '../models/package_option.dart';
import '../services/odoo_client.dart';

class OperationDetailController extends ChangeNotifier {
  OperationDetailController(this.client, this.url, this.operationId);
  final OdooClient client;
  final String url;
  final int operationId;

  List<OperationLine> lines = <OperationLine>[];
  bool loading = false;
  bool saving = false;
  String? error;
  int? lastScannedLineId;
  final Map<String, int> _scanCodeToProductId = <String, int>{};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      lines = await client.getOperationLines(url, operationId);
      _scanCodeToProductId.clear();
      final productCodes = await client.getProductScanCodes(
        url,
        lines.where((line) => line.productId != null).map((line) => line.productId!),
      );
      for (final entry in productCodes.entries) {
        for (final code in entry.value) {
          _scanCodeToProductId[code.toLowerCase()] = entry.key;
        }
      }
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> increment(int lineId) async {
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;
    final line = lines[index];
    await setQuantity(lineId, line.doneQuantity + 1);
  }

  Future<void> setQuantity(int lineId, double quantity) async {
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;
    final line = lines[index];
    final safeQuantity = quantity.clamp(0, line.expectedQuantity).toDouble();
    saving = true;
    error = null;
    notifyListeners();
    try {
      await client.setMoveQuantity(
        url,
        line.moveId,
        line.moveLineIds,
        safeQuantity,
      );
      lines[index] = lines[index].copyWith(doneQuantity: safeQuantity);
      lastScannedLineId = lineId;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<OperationLine?> scan(String barcode) async {
    final normalizedBarcode = barcode.trim();
    final productId = _scanCodeToProductId[normalizedBarcode.toLowerCase()] ??
        await client.findProductByBarcode(url, normalizedBarcode);
    if (productId == null) {
      throw Exception('Aucun produit trouvé pour ce code-barres');
    }
    final line = lines.cast<OperationLine?>().firstWhere(
      (item) =>
          item?.productId == productId &&
          item!.doneQuantity < item.expectedQuantity,
      orElse: () => null,
    );
    if (line == null) {
      throw Exception('Ce produit ne fait pas partie de cette opération');
    }
    await increment(line.id);
    if (error != null) throw Exception(error);
    return line;
  }

  Future<String> putInPack() async {
    saving = true;
    notifyListeners();
    try {
      await client.putInPack(url, operationId);
      await load();
      final packages = lines
          .map((line) => line.destinationPackage)
          .where((name) => name.isNotEmpty)
          .toSet();
      return packages.isEmpty ? 'Nouveau colis' : packages.join(', ');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<List<PackageOption>> getPackages({String query = ''}) =>
      client.getPackages(url, query: query);

  Future<PackageOption> createPackage(String name) =>
      client.createPackage(url, name);

  Future<void> assignPackage(
    OperationLine line,
    PackageOption? package, {
    bool source = false,
  }) async {
    saving = true;
    notifyListeners();
    try {
      await client.assignPackageToLines(
        url,
        line.moveLineIds,
        package?.id,
        source: source,
      );
      await load();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> assignGlobalPackage(PackageOption? package) async {
    saving = true;
    notifyListeners();
    try {
      await client.assignPackageToOperation(url, operationId, package?.id);
      await load();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<dynamic> validate() async {
    saving = true;
    notifyListeners();
    try {
      return await client.validateOperation(url, operationId);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> confirmValidationAction(
    Map<dynamic, dynamic> action, {
    bool createBackorder = true,
  }) async {
    saving = true;
    notifyListeners();
    try {
      await client.processValidationAction(
        url,
        action,
        createBackorder: createBackorder,
      );
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
