import 'package:flutter/foundation.dart';
import '../models/reception_type.dart';
import '../services/odoo_client.dart';
import '../services/preferences_service.dart';

class ReceptionController extends ChangeNotifier {
  ReceptionController(this.client, this.url, {PreferencesService? preferences})
    : preferences = preferences ?? PreferencesService();
  final OdooClient client;
  final String url;
  final PreferencesService preferences;
  List<ReceptionType> types = <ReceptionType>[];
  Set<int> hiddenTypeIds = <int>{};
  bool loading = false;
  String? error;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifyIfMounted() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    loading = true;
    error = null;
    _notifyIfMounted();
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        client.getReceptionTypes(url),
        preferences.loadHiddenOperationTypeIds(url),
      ]);
      if (_disposed) return;
      types = values[0] as List<ReceptionType>;
      hiddenTypeIds = values[1] as Set<int>;
    } catch (exception) {
      if (_disposed) return;
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!_disposed) {
        loading = false;
        _notifyIfMounted();
      }
    }
  }

  bool isHidden(int typeId) => hiddenTypeIds.contains(typeId);

  Future<void> toggleVisibility(int typeId) async {
    if (_disposed) return;
    if (!hiddenTypeIds.add(typeId)) hiddenTypeIds.remove(typeId);
    _notifyIfMounted();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }

  Future<void> showAllTypes() async {
    if (_disposed) return;
    hiddenTypeIds.clear();
    _notifyIfMounted();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }

  Future<void> hideAllTypes() async {
    if (_disposed) return;
    hiddenTypeIds = types.map((type) => type.id).toSet();
    _notifyIfMounted();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }
}
