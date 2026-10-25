import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/scanned_document.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'document_detail_screen.dart';

class IdCardScannerScreen extends StatefulWidget {
  const IdCardScannerScreen({super.key});

  @override
  State<IdCardScannerScreen> createState() => _IdCardScannerScreenState();
}

class _IdCardScannerScreenState extends State<IdCardScannerScreen> {
  final ScannerService _scannerService = ScannerService();
  final StorageService _storageService = StorageService();

  String? _frontImagePath;
  String? _backImagePath;
  bool _isProcessing = false;

  Future<void> _captureFront() async {
    final path = await _scannerService.capturePhoto();
    if (path != null) {
      setState(() {
        _frontImagePath = path;
      });
    }
  }

  Future<void> _captureBack() async {
    final path = await _scannerService.capturePhoto();
    if (path != null) {
      setState(() {
        _backImagePath = path;
      });
    }
  }

  Future<void> _stitchAndSave() async {
    if (_frontImagePath == null || _backImagePath == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Decode front and back images
      final frontBytes = await File(_frontImagePath!).readAsBytes();
      final backBytes = await File(_backImagePath!).readAsBytes();

      img.Image? frontImg = img.decodeImage(frontBytes);
      img.Image? backImg = img.decodeImage(backBytes);

      if (frontImg != null && backImg != null) {
        // Standard A4 aspect canvas (1240 x 1754 px at 150 DPI)
        const canvasWidth = 1240;
        const canvasHeight = 1754;
        final canvas = img.Image(width: canvasWidth, height: canvasHeight);
        img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

        // Scale images to fit half page nicely (with margins)
        const targetWidth = 1000;
        final scaledFront = img.copyResize(frontImg, width: targetWidth);
        final scaledBack = img.copyResize(backImg, width: targetWidth);

        // Composite Front at top center
        final frontX = (canvasWidth - scaledFront.width) ~/ 2;
        const frontY = 140;
        img.compositeImage(canvas, scaledFront, dstX: frontX, dstY: frontY);

        // Composite Back at bottom center
        final backX = (canvasWidth - scaledBack.width) ~/ 2;
        const backY = 900;
        img.compositeImage(canvas, scaledBack, dstX: backX, dstY: backY);

        // Save stitched image
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
        if (!await scansDir.exists()) await scansDir.create(recursive: true);

        final outputPath = p.join(
          scansDir.path,
          'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final jpgBytes = img.encodeJpg(canvas, quality: 90);
        await File(outputPath).writeAsBytes(jpgBytes);

        // Create ScannedDocument
        final doc = ScannedDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'ID Card Scan ${DateTime.now().day}/${DateTime.now().month}',
          pagePaths: [outputPath],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tag: 'ID Cards',
        );

        await _storageService.saveDocument(doc);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: doc),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ID Card page: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Scanner Mode'),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Merging front and back onto A4 page...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Scan both sides of your ID Card or Driver License. ScanCraft will automatically place them onto a single A4 printable page.',
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  // Front Side Slot
                  _buildSlot(
                    label: '1. Front Side',
                    imagePath: _frontImagePath,
                    onTap: _captureFront,
                    icon: Icons.credit_card,
                  ),
                  const SizedBox(height: 20),
                  // Back Side Slot
                  _buildSlot(
                    label: '2. Back Side',
                    imagePath: _backImagePath,
                    onTap: _captureBack,
                    icon: Icons.flip_to_back,
                  ),
                  const SizedBox(height: 32),
                  // Generate Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_frontImagePath != null && _backImagePath != null)
                        ? _stitchAndSave
                        : null,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      'Combine to Single Page',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSlot({
    required String label,
    required String? imagePath,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: imagePath != null ? AppTheme.primary : Colors.grey.shade300,
                width: imagePath != null ? 2 : 1,
              ),
            ),
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(File(imagePath), fit: BoxFit.cover, width: double.infinity),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 40, color: AppTheme.primary),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to capture photo',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
