import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../update_dialog.dart';

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.compact = false});

  final bool compact;
  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        final text = 'Version ${info.version} (${info.buildNumber})';
        if (compact) {
          return InkWell(
            onTap: () => showReleaseHistoryDialog(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }
        return ActionChip(
          onPressed: () => showReleaseHistoryDialog(context),
          avatar: const Icon(Icons.info_outline, size: 17),
          label: Text(text),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}
