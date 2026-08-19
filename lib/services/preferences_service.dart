import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _rememberKey = 'remember_me';
  static const _urlKey = 'odoo_url';
  static const _databaseKey = 'odoo_db';
  static const _emailKey = 'odoo_email';
  static const _passwordKey = 'odoo_password';

  String _hiddenOperationTypesKey(String url) =>
      'hidden_operation_types_${base64Url.encode(utf8.encode(url))}';

  Future<Set<int>> loadHiddenOperationTypeIds(String url) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_hiddenOperationTypesKey(url)) ??
            <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<void> saveHiddenOperationTypeIds(String url, Set<int> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final values = ids.map((id) => id.toString()).toList()..sort();
    await preferences.setStringList(_hiddenOperationTypesKey(url), values);
  }

  Future<Map<String, String>> loadLogin() async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_rememberKey) ?? false)) {
      return <String, String>{};
    }
    return <String, String>{
      'url': preferences.getString(_urlKey) ?? '',
      'db': preferences.getString(_databaseKey) ?? '',
      'email': preferences.getString(_emailKey) ?? '',
      'password': preferences.getString(_passwordKey) ?? '',
    };
  }

  Future<void> saveLogin({
    required bool remember,
    required String url,
    required String db,
    required String email,
    required String password,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberKey, remember);
    if (remember) {
      await preferences.setString(_urlKey, url);
      await preferences.setString(_databaseKey, db);
      await preferences.setString(_emailKey, email);
      await preferences.setString(_passwordKey, password);
    } else {
      await Future.wait(<Future<bool>>[
        preferences.remove(_urlKey),
        preferences.remove(_databaseKey),
        preferences.remove(_emailKey),
        preferences.remove(_passwordKey),
      ]);
    }
  }
}
