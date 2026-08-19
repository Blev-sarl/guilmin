import 'package:flutter/foundation.dart';
import '../models/reception_type.dart';
import '../services/odoo_client.dart';

class ReceptionController extends ChangeNotifier {
  ReceptionController(this.client, this.url);
  final OdooClient client;
  final String url;
  List<ReceptionType> types = <ReceptionType>[];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      types = await client.getReceptionTypes(url);
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
