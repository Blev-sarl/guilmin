import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});
  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  bool detected = false;
  String? startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startCamera());
  }

  Future<void> startCamera() async {
    try {
      await controller.start();
    } on MobileScannerException catch (error) {
      if (mounted) {
        setState(() => startupError = error.errorCode.name);
      }
    } catch (error) {
      if (mounted) {
        setState(() => startupError = error.toString());
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onDetect(BarcodeCapture capture) {
    if (detected) return;
    String? value;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue?.isNotEmpty == true) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null) return;
    detected = true;
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner un produit')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Le scanner caméra n’est pas disponible sur cette plateforme. Utilisez la saisie manuelle du code-barres.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (startupError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner un produit')),
        body: _CameraError(
          message: startupError!,
          onRetry: () {
            setState(() => startupError = null);
            startCamera();
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un produit'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Flash',
            onPressed: controller.toggleTorch,
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Changer de caméra',
            onPressed: controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
            onDetectError: (error, stackTrace) {},
            errorBuilder: (context, error) => _CameraError(
              message: error.errorCode.name,
              onRetry: startCamera,
            ),
          ),
          Center(
            child: Container(
              width: 290,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF74B47D), width: 3),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 42,
            child: Text(
              'Placez le code-barres ou la référence dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              'Impossible d’ouvrir la caméra. Autorisez la caméra dans les réglages de l’appareil.\n\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Saisie manuelle'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
