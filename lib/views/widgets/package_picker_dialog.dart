import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/package_option.dart';

class PackagePickerDialog extends StatefulWidget {
  const PackagePickerDialog({
    super.key,
    required this.loadPackages,
    this.createPackage,
    this.allowNone = true,
  });
  final Future<List<PackageOption>> Function(String query) loadPackages;
  final Future<PackageOption> Function(String name)? createPackage;
  final bool allowNone;

  @override
  State<PackagePickerDialog> createState() => _PackagePickerDialogState();
}

class _PackagePickerDialogState extends State<PackagePickerDialog> {
  final input = TextEditingController();
  List<PackageOption> packages = <PackageOption>[];
  bool loading = true;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> load([String query = '']) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      packages = await widget.loadPackages(query);
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void search(String value) {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 350),
      () => load(value.trim()),
    );
  }

  Future<void> create() async {
    final name = input.text.trim();
    if (name.isEmpty || widget.createPackage == null) return;
    setState(() => loading = true);
    try {
      final package = await widget.createPackage!(name);
      if (mounted) Navigator.of(context).pop(package);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = exception.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sélectionner un colis'),
    content: SizedBox(
      width: 520,
      height: 430,
      child: Column(
        children: <Widget>[
          TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du colis',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: search,
            onSubmitted: (_) => widget.createPackage == null ? null : create(),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      if (widget.allowNone)
                        ListTile(
                          leading: const Icon(Icons.link_off),
                          title: const Text('Aucun colis'),
                          onTap: () => Navigator.of(context).pop(
                            const PackageOption(
                              id: -1,
                              name: '',
                              location: '',
                              container: '',
                            ),
                          ),
                        ),
                      ...packages.map(
                        (package) => ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(package.name),
                          subtitle: package.location.isEmpty
                              ? null
                              : Text(package.location),
                          onTap: () => Navigator.of(context).pop(package),
                        ),
                      ),
                      if (packages.isEmpty && input.text.trim().isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Aucun colis trouvé',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      if (widget.createPackage != null)
        FilledButton.icon(
          onPressed: loading || input.text.trim().isEmpty ? null : create,
          icon: const Icon(Icons.add),
          label: const Text('Créer ce colis'),
        ),
    ],
  );
}
