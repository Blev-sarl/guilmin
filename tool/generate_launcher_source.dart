import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(
    File('assets/images/guilmin_logo.png').readAsBytesSync(),
  )!;
  final boar = img.copyCrop(
    source,
    x: 0,
    y: 0,
    width: 690,
    height: source.height,
  );
  final resized = img.copyResize(boar, width: 820);
  final canvas = img.Image(width: 1024, height: 1024);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(
    canvas,
    resized,
    dstX: (canvas.width - resized.width) ~/ 2,
    dstY: (canvas.height - resized.height) ~/ 2,
  );
  File(
    'assets/images/guilmin_app_icon.png',
  ).writeAsBytesSync(img.encodePng(canvas));
}
