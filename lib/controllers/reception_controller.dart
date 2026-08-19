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

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        client.getReceptionTypes(url),
        preferences.loadHiddenOperationTypeIds(url),
      ]);
      types = values[0] as List<ReceptionType>;
      hiddenTypeIds = values[1] as Set<int>;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isHidden(int typeId) => hiddenTypeIds.contains(typeId);

  Future<void> toggleVisibility(int typeId) async {
    if (!hiddenTypeIds.add(typeId)) hiddenTypeIds.remove(typeId);
    notifyListeners();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }

  Future<void> showAllTypes() async {
    hiddenTypeIds.clear();
    notifyListeners();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }

  Future<void> hideAllTypes() async {
    hiddenTypeIds = types.map((type) => type.id).toSet();
    notifyListeners();
    await preferences.saveHiddenOperationTypeIds(url, hiddenTypeIds);
  }
}
