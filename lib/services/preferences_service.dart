import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final Future<SharedPreferences> _instance =
      SharedPreferences.getInstance();

  Future<SharedPreferences> get _preferences => _instance;
  static const _rememberKey = 'remember_me';
  static const _urlKey = 'odoo_url';
  static const _databaseKey = 'odoo_db';
  static const _emailKey = 'odoo_email';
  static const _passwordKey = 'odoo_password';
  static const _printerKey = 'selected_printer';
  static const _printerIpKey = 'zpl_printer_ip';
  static const _printerPortKey = 'zpl_printer_port';
  static const _zplTemplateKey = 'zpl_template';
  static const _zplPriceKey = 'zpl_with_price';
  static const _hiddenPackageReportsKey = 'hidden_package_reports';

  Future<Set<String>> loadHiddenPackageReports() async {
    final p = await _preferences;
    return (p.getStringList(_hiddenPackageReportsKey) ?? <String>[]).toSet();
  }

  Future<void> saveHiddenPackageReports(Set<String> reports) async {
    final p = await _preferences;
    await p.setStringList(_hiddenPackageReportsKey, reports.toList()..sort());
  }

  Future<Map<String, dynamic>> loadZplPrinter() async {
    final p = await _preferences;
    return {'ip': p.getString(_printerIpKey) ?? '', 'port': p.getInt(_printerPortKey) ?? 9100, 'template': p.getString(_zplTemplateKey) ?? 'normal', 'withPrice': p.getBool(_zplPriceKey) ?? false};
  }

  Future<void> saveZplPrinter({required String ip, required int port, required String template, required bool withPrice}) async {
    final p = await _preferences;
    await Future.wait([p.setString(_printerIpKey, ip), p.setInt(_printerPortKey, port), p.setString(_zplTemplateKey, template), p.setBool(_zplPriceKey, withPrice)]);
  }

  Future<String?> loadPrinter() async {
    final preferences = await _preferences;
    return preferences.getString(_printerKey);
  }

  Future<void> savePrinter(String? printer) async {
    final preferences = await _preferences;
    if (printer == null || printer.isEmpty) {
      await preferences.remove(_printerKey);
    } else {
      await preferences.setString(_printerKey, printer);
    }
  }

  String _hiddenOperationTypesKey(String url) =>
      'hidden_operation_types_${base64Url.encode(utf8.encode(url))}';

  Future<Set<int>> loadHiddenOperationTypeIds(String url) async {
    final preferences = await _preferences;
    return (preferences.getStringList(_hiddenOperationTypesKey(url)) ??
            <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<void> saveHiddenOperationTypeIds(String url, Set<int> ids) async {
    final preferences = await _preferences;
    final values = ids.map((id) => id.toString()).toList()..sort();
    await preferences.setStringList(_hiddenOperationTypesKey(url), values);
  }

  Future<Map<String, String>> loadLogin() async {
    final preferences = await _preferences;
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
    final preferences = await _preferences;
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
