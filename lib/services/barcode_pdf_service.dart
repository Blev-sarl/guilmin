import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BarcodePdfItem {
  const BarcodePdfItem({required this.code, required this.name});
  final String code;
  final String name;
}

class BarcodePdfService {
  Future<List<int>> build({
    required List<BarcodePdfItem> items,
    required int columns,
    required int rows,
  }) async {
    final document = pw.Document();
    final barcode = Barcode.code128();
    final perPage = columns * rows;
    for (var offset = 0; offset < items.length; offset += perPage) {
      final pageItems = items.skip(offset).take(perPage).toList();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.GridView(
            crossAxisCount: columns,
            childAspectRatio: 1.35,
            children: pageItems
                .map(
                  (item) => pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: <pw.Widget>[
                        pw.Text(
                          item.name,
                          maxLines: 2,
                          style: pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 5),
                        pw.BarcodeWidget(
                          barcode: barcode,
                          data: item.code,
                          width: 100,
                          height: 38,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(item.code, style: pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    return document.save();
  }
}
