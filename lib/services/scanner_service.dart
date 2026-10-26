import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Launch Google ML Kit Document Scanner
  Future<List<String>> startDocumentScan({int pageLimit = 20}) async {
    try {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,            // Full editing UI (crop, filters, rotation)
        pageLimit: pageLimit,
      );

      final documentScanner = DocumentScanner(options: options);
      final DocumentScanningResult result = await documentScanner.scanDocument();

      if (result.images.isNotEmpty) {
        return await _copyImagesToAppDir(result.images);
      }
    } catch (e) {
      print('ScannerService scan error: $e');
    }
    return [];
  }

  /// Pick images from device gallery as pages
  Future<List<String>> pickFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        final paths = pickedFiles.map((file) => file.path).toList();
        return await _copyImagesToAppDir(paths);
      }
    } catch (e) {
      print('ScannerService gallery error: $e');
    }
    return [];
  }

  /// Single photo capture from regular camera (used for ID card / quick captures)
  Future<String?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (photo != null) {
        final copied = await _copyImagesToAppDir([photo.path]);
        return copied.isNotEmpty ? copied.first : null;
      }
    } catch (e) {
      print('ScannerService capture error: $e');
    }
    return null;
  }

  /// Persist scanned images in the application documents directory
  Future<List<String>> _copyImagesToAppDir(List<String> tempPaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }

    List<String> persistentPaths = [];
    for (var tempPath in tempPaths) {
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}_${p.basename(tempPath)}';
      final savedFile = await File(tempPath).copy(p.join(scansDir.path, fileName));
      persistentPaths.add(savedFile.path);
    }
    return persistentPaths;
  }
}
