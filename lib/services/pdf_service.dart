import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

enum PdfQuality { high, medium, low }

class PdfService {
  /// Generate a multi-page PDF from a list of scanned image paths
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String title,
    String? watermarkText,
    PdfQuality quality = PdfQuality.high,
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'ScanCraft',
    );

    for (int i = 0; i < imagePaths.length; i++) {
      final imageFile = File(imagePaths[i]);
      if (!await imageFile.exists()) continue;

      final Uint8List imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
                // Optional Watermark (CamScanner style)
                if (watermarkText != null && watermarkText.isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotateBox(
                      angle: -0.5,
                      child: pw.Opacity(
                        opacity: 0.18,
                        child: pw.Text(
                          watermarkText,
                          style: pw.TextStyle(
                            fontSize: 48,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Page Number footer
                pw.Positioned(
                  bottom: 0,
                  right: 0,
                  child: pw.Text(
                    'Page ${i + 1} of ${imagePaths.length}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(appDir.path, 'scancraft_pdfs'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final filePath = p.join(
      pdfDir.path,
      '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  /// Share the PDF file to WhatsApp, Drive, Gmail, etc.
  Future<void> sharePdf(String pdfPath, {String? text}) async {
    final file = XFile(pdfPath);
    await Share.shareXFiles([file], text: text ?? 'Scanned with ScanCraft');
  }

  /// Open and view the PDF in the device default viewer
  Future<void> openPdf(String pdfPath) async {
    await OpenFilex.open(pdfPath);
  }
}
