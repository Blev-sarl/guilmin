import 'dart:io';
import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class ZplPrinterService {
  Future<File> saveZplFile(String zpl, String name) async {
    if (zpl.trim().isEmpty) throw Exception('Le contenu ZPL est vide');
    final directory = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName.zpl');
    await file.writeAsBytes(utf8.encode(zpl), flush: true);
    debugPrint('Fichier ZPL enregistré : ${file.path}');
    return file;
  }

  Future<void> printPdf({
    required Uint8List pdfBytes,
    required String ip,
    required int port,
    int dpi = 203,
    double widthMm = 71,
    double heightMm = 107,
    int rotation = 0,
  }) async {
    final zpl = await convertPdfToZpl(pdfBytes: pdfBytes, dpi: dpi, widthMm: widthMm, heightMm: heightMm, rotation: rotation);
    await sendZpl(zpl: zpl, ip: ip, port: port);
  }

  Future<String> convertPdfToZpl({
    required Uint8List pdfBytes,
    int dpi = 203,
    double widthMm = 71,
    double heightMm = 107,
    int rotation = 0,
  }) async {
    debugPrint('ZPL: conversion PDF démarrée');
    final zpl = StringBuffer();
    await for (final raster in Printing.raster(pdfBytes, dpi: dpi.toDouble())) {
      final png = await raster.toPng();
      final image = img.decodeImage(png);
      if (image == null) throw Exception('Impossible de convertir le PDF en image');
      final targetWidth = (widthMm * dpi / 25.4).round();
      final targetHeight = (heightMm * dpi / 25.4).round();
      final rotated = rotation == 0 ? image : img.copyRotate(image, angle: rotation);
      final resized = img.copyResize(rotated, width: targetWidth, height: targetHeight);
      zpl.write(_imageToZpl(_flattenOnWhite(resized)));
    }
    debugPrint('ZPL: conversion terminée (${zpl.length} caractères)');
    final payload = zpl.toString();
    _logZpl(payload, 'généré');
    return payload;
  }

  Future<void> sendZpl({required String zpl, required String ip, required int port}) async {
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    try {
      final payload = zpl;
      debugPrintSynchronously('===== ZPL envoyé à $ip:$port =====');
      for (var start = 0; start < payload.length; start += 800) {
        final end = (start + 800).clamp(0, payload.length);
        debugPrintSynchronously(payload.substring(start, end));
      }
      debugPrintSynchronously('===== FIN ZPL =====');
      socket.add(payload.codeUnits);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  void _logZpl(String payload, String status) {
    debugPrintSynchronously('===== ZPL $status =====');
    for (var start = 0; start < payload.length; start += 800) {
      final end = (start + 800).clamp(0, payload.length);
      debugPrintSynchronously(payload.substring(start, end));
    }
    debugPrintSynchronously('===== FIN ZPL =====');
  }

  String _imageToZpl(img.Image source) {
    final width = source.width;
    final bytesPerRow = (width + 7) ~/ 8;
    final data = StringBuffer();
    for (var y = 0; y < source.height; y++) {
      for (var byte = 0; byte < bytesPerRow; byte++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = byte * 8 + bit;
          if (x >= width) continue;
          final pixel = source.getPixel(x, y);
          final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
          if (luminance < 160) value |= 1 << (7 - bit);
        }
        data.write(value.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return '^XA^PW$width^LL${source.height}^FO0,0^GFA,${data.length ~/ 2},${data.length ~/ 2},$bytesPerRow,$data^XZ';
  }

  img.Image _flattenOnWhite(img.Image source) {
    final result = img.Image(width: source.width, height: source.height);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a / 255.0;
        final red = (pixel.r * alpha + 255 * (1 - alpha)).round();
        final green = (pixel.g * alpha + 255 * (1 - alpha)).round();
        final blue = (pixel.b * alpha + 255 * (1 - alpha)).round();
        result.setPixelRgb(x, y, red, green, blue);
      }
    }
    return result;
  }
}
