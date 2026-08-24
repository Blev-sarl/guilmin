import 'package:flutter/material.dart';
import '../controllers/login_controller.dart';
import 'login_page.dart';
import 'reception_types_page.dart';
import 'update_dialog.dart';
import 'widgets/app_version_label.dart';
import 'print_settings_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (user == null || controller.url == null) {
      return LoginPage(controller: controller);
    }
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/guilmin_logo.png',
          width: 145,
          height: 42,
          cacheWidth: 320,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'Guilmin',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Paramètres d’impression',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrintSettingsPage()),
            ),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Vérifier les mises à jour',
            onPressed: () => showUpdateDialog(context),
            icon: const Icon(Icons.system_update_outlined),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () {
              controller.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => LoginPage(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Bonjour ${user.name.isEmpty ? user.login : user.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: AppVersionLabel(),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner, size: 36),
              title: const Text(
                'Opérations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Réceptions, livraisons et transferts internes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceptionTypesPage(
                    client: controller.client,
                    url: controller.url!,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
