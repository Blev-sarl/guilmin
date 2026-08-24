import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/github_update_service.dart';

final GitHubUpdateService _updateService = GitHubUpdateService();

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Laisser le premier écran se dessiner avant l'appel réseau GitHub.
      // Cela évite de concurrencer le rendu initial sur les appareils lents.
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) showUpdateDialog(context, silent: true);
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showUpdateDialog(
  BuildContext context, {
  bool silent = false,
}) async {
  try {
    final release = await _updateService.getAvailableUpdate();
    if (!context.mounted) return;
    if (release == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L’application est à jour.')),
        );
      }
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDownloadDialog(release: release),
    );
  } catch (error) {
    if (!context.mounted || silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

Future<void> showReleaseHistoryDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _ReleaseHistoryDialog(),
  );
}

class _ReleaseHistoryDialog extends StatefulWidget {
  const _ReleaseHistoryDialog();

  @override
  State<_ReleaseHistoryDialog> createState() => _ReleaseHistoryDialogState();
}

class _ReleaseHistoryDialogState extends State<_ReleaseHistoryDialog> {
  late final Future<(PackageInfo, List<AppRelease>)> _data = _load();

  Future<(PackageInfo, List<AppRelease>)> _load() async {
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      PackageInfo.fromPlatform(),
      _updateService.getReleases(),
    ]);
    return (values[0] as PackageInfo, values[1] as List<AppRelease>);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Versions disponibles'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<(PackageInfo, List<AppRelease>)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
              );
            }
            final (package, releases) = snapshot.data!;
            if (releases.isEmpty) {
              return const Text(
                'Aucune Release GitHub contenant un APK n’est disponible.',
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: releases.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final release = releases[index];
                  final installed = _sameVersion(
                    release.version,
                    package.version,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      installed ? Icons.check_circle : Icons.android,
                      color: installed
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    title: Text(release.name),
                    subtitle: Text(
                      installed
                          ? '${release.version} • Version installée'
                          : release.version,
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: installed
                          ? 'Réinstaller cette version'
                          : 'Télécharger et installer',
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              _UpdateDownloadDialog(release: release),
                        );
                      },
                      icon: const Icon(Icons.download),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  bool _sameVersion(String release, String installed) {
    final releaseParts = RegExp(r'\d+').allMatches(release).take(3);
    final installedParts = RegExp(r'\d+').allMatches(installed).take(3);
    return releaseParts.map((item) => item.group(0)).join('.') ==
        installedParts.map((item) => item.group(0)).join('.');
  }
}

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({required this.release});
  final AppRelease release;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  double? _progress;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      final apk = await _updateService.downloadApk(
        widget.release,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _updateService.installApk(apk);
    } catch (error) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      icon: const Icon(Icons.system_update, size: 38),
      title: Text('Mise à jour ${widget.release.version}'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.release.name),
            if (widget.release.notes.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(child: Text(widget.release.notes)),
              ),
            ],
            if (downloading) ...<Widget>[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _progress == 1
                    ? 'Téléchargement terminé, ouverture de l’installation…'
                    : '${((_progress ?? 0) * 100).round()} %',
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Plus tard'),
        ),
        FilledButton.icon(
          onPressed: downloading ? null : _download,
          icon: const Icon(Icons.download),
          label: Text(_error == null ? 'Mettre à jour' : 'Réessayer'),
        ),
      ],
    );
  }
}
