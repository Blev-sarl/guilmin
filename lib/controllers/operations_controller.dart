import 'package:flutter/foundation.dart';
import '../models/stock_operation.dart';
import '../services/odoo_client.dart';

class OperationsController extends ChangeNotifier {
  OperationsController(this.client, this.url, this.pickingTypeId);

  final OdooClient client;
  final String url;
  final int pickingTypeId;
  List<StockOperation> operations = <StockOperation>[];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      operations = await client.getOperations(url, pickingTypeId);
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
