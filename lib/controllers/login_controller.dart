import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/odoo_client.dart';
import '../services/preferences_service.dart';

class LoginController extends ChangeNotifier {
  LoginController(this.client, this.preferences);
  final OdooClient client;
  final PreferencesService preferences;
  bool loading = false;
  String? error;
  String? url;
  OdooUser? user;

  Future<Map<String, String>> loadSaved() => preferences.loadLogin();

  Future<bool> login({
    required String url,
    required String db,
    required String email,
    required String password,
    required bool remember,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await client.authenticate(
        url: url,
        database: db,
        email: email,
        password: password,
      );
      this.url = url;
      await preferences.saveLogin(
        remember: remember,
        url: url,
        db: db,
        email: email,
        password: password,
      );
      return true;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void logout() {
    user = null;
    url = null;
    error = null;
  }
}
