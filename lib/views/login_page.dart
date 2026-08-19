import 'package:flutter/material.dart';
import '../controllers/login_controller.dart';
import 'dashboard_page.dart';

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
                        fit: BoxFit.contain,
                        semanticLabel: 'Guilmin',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Odoo Picking',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
