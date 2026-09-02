import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/login_controller.dart';
import 'dashboard_page.dart';
import 'camera_scanner_page.dart';
import 'widgets/app_version_label.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final LoginController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController(text: 'https://odoo.example.com');
  final _database = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final saved = await widget.controller.loadSaved();
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _url.text = saved['url'] ?? _url.text;
      _database.text = saved['db'] ?? '';
      _email.text = saved['email'] ?? '';
      _password.text = saved['password'] ?? '';
      _remember = true;
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await widget.controller.login(
      url: _url.text.trim(),
      db: _database.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      remember: _remember,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(controller: widget.controller),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error ?? 'Connexion impossible'),
        ),
      );
    }
  }

  Future<void> _scanOdooQrCode() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const CameraScannerPage(
          title: 'Connexion Odoo par QR code',
          instruction: 'Placez le QR code Odoo dans le cadre',
        ),
      ),
    );
    if (!mounted || value == null) return;
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.queryParameters.isNotEmpty) data = uri.queryParameters;
    }
    final url = data?['url'] ?? data?['odoo_url'] ?? data?['host'];
    final db = data?['db'] ?? data?['database'];
    final email = data?['email'] ?? data?['login'] ?? data?['username'];
    final password = data?['password'] ?? data?['passwd'];
    if ([url, db, email, password].any((item) => item == null || item.toString().isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code Odoo non reconnu')));
      return;
    }
    setState(() {
      _url.text = url.toString();
      _database.text = db.toString();
      _email.text = email.toString();
      _password.text = password.toString();
      _remember = true;
    });
    await _submit();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _url.dispose();
    _database.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/guilmin_logo.png',
                        height: 72,
                        // Le logo est affiché à ~144 px de haut au maximum.
                        // Limiter le décodage réduit le coût du premier frame.
                        cacheWidth: 320,
                        fit: BoxFit.contain,
                        semanticLabel: 'Guilmin',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Guilmin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AppVersionLabel(compact: true),
                      const SizedBox(height: 24),
                      _field(_url, 'URL Odoo', Icons.link),
                      const SizedBox(height: 14),
                      _field(_database, 'Base de données', Icons.storage),
                      const SizedBox(height: 14),
                      _field(
                        _email,
                        'Email ou identifiant',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Mot de passe requis'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        value: _remember,
                        onChanged: (value) =>
                            setState(() => _remember = value ?? false),
                        title: const Text('Se souvenir de moi'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      FilledButton.icon(
                        onPressed: widget.controller.loading ? null : _submit,
                        icon: widget.controller.loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          widget.controller.loading
                              ? 'Connexion…'
                              : 'Se connecter',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: widget.controller.loading ? null : _scanOdooQrCode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Connexion par QR code Odoo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label requis' : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
