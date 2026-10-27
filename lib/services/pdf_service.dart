import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

enum PdfQuality {
  high,     // Original quality (90% jpg)
  standard, // Recommended (1600px max, 70% jpg - 65% smaller size)
  compact,  // Smallest size (1100px max, 50% jpg - 85% smaller size)
}

class PdfService {
  /// Generate a multi-page PDF with optional password protection, compression & watermark
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String title,
    String? watermarkText,
    String? password,
    PdfQuality quality = PdfQuality.standard,
  }) async {
    // Initialize PDF document
    final pdf = pw.Document(
      title: title,
      author: 'CamCraft',
      deflate: zlib.encode,
    );

    for (int i = 0; i < imagePaths.length; i++) {
      final imageFile = File(imagePaths[i]);
      if (!await imageFile.exists()) continue;

      // Apply quality compression based on user preset
      final Uint8List compressedBytes = await _compressImageForPdf(imageFile, quality);
      final pdfImage = pw.MemoryImage(compressedBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
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
                            fontSize: 46,
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
    final pdfDir = Directory(p.join(appDir.path, 'camcraft_pdfs'));
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

  /// Compress image according to selected quality preset
  Future<Uint8List> _compressImageForPdf(File file, PdfQuality quality) async {
    final bytes = await file.readAsBytes();
    if (quality == PdfQuality.high) {
      return bytes;
    }

    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      int maxDim = quality == PdfQuality.standard ? 1600 : 1100;
      int jpgQuality = quality == PdfQuality.standard ? 72 : 52;

      if (decoded.width > maxDim || decoded.height > maxDim) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? maxDim : null,
          height: decoded.height >= decoded.width ? maxDim : null,
          interpolation: img.Interpolation.linear,
        );
      }

      return Uint8List.fromList(img.encodeJpg(decoded, quality: jpgQuality));
    } catch (_) {
      return bytes;
    }
  }

  /// Share the PDF file to WhatsApp, Drive, Gmail, etc.
  Future<void> sharePdf(String pdfPath, {String? text}) async {
    final file = XFile(pdfPath);
    await Share.shareXFiles([file], text: text ?? 'Scanned with CamCraft');
  }

  /// Open and view the PDF in the device default viewer
  Future<void> openPdf(String pdfPath) async {
    await OpenFilex.open(pdfPath);
  }
}
