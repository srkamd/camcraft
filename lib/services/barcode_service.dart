import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class ScannedBarcodeResult {
  final String rawValue;
  final BarcodeFormat format;
  final BarcodeType type;

  ScannedBarcodeResult({
    required this.rawValue,
    required this.format,
    required this.type,
  });
}

class BarcodeService {
  final BarcodeScanner _scanner = BarcodeScanner();

  /// Scan an image file for QR codes or barcodes
  Future<List<ScannedBarcodeResult>> scanImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final List<Barcode> barcodes = await _scanner.processImage(inputImage);

      return barcodes
          .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
          .map((b) => ScannedBarcodeResult(
                rawValue: b.rawValue!,
                format: b.format,
                type: b.type,
              ))
          .toList();
    } catch (e) {
      print('Barcode scan error: $e');
      return [];
    }
  }

  void dispose() {
    _scanner.close();
  }
}
