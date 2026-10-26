import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scanned_document.dart';
import '../services/barcode_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final BarcodeService _barcodeService = BarcodeService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _isScanning = false;
  ScannedBarcodeResult? _result;
  String? _scannedImagePath;

  @override
  void initState() {
    super.initState();
    // Auto-launch camera when screen opens for fast scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureFromCamera();
    });
  }

  @override
  void dispose() {
    _barcodeService.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      _processImage(photo.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      _processImage(photo.path);
    }
  }

  Future<void> _processImage(String imagePath) async {
    setState(() {
      _isScanning = true;
      _scannedImagePath = imagePath;
      _result = null;
    });

    final results = await _barcodeService.scanImage(imagePath);

    setState(() {
      _isScanning = false;
      if (results.isNotEmpty) {
        _result = results.first;
      }
    });

    if (results.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code or Barcode found in image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyResult() {
    if (_result == null) return;
    Clipboard.setData(ClipboardData(text: _result!.rawValue));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAsDocumentNote() async {
    if (_result == null || _scannedImagePath == null) return;

    final now = DateTime.now();
    final newDoc = ScannedDocument(
      id: now.millisecondsSinceEpoch.toString(),
      title: 'QR Scan: ${_result!.rawValue.length > 20 ? _result!.rawValue.substring(0, 20) + "..." : _result!.rawValue}',
      pagePaths: [_scannedImagePath!],
      createdAt: now,
      updatedAt: now,
      tag: 'Notes',
    );

    await _storageService.saveDocument(newDoc);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Documents as Note!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = _result != null &&
        (_result!.type == BarcodeType.url ||
            _result!.rawValue.startsWith('http://') ||
            _result!.rawValue.startsWith('https://') ||
            _result!.rawValue.startsWith('www.'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR & Barcode Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Pick from Gallery',
            onPressed: _pickFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Take Photo',
            onPressed: _captureFromCamera,
          ),
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Reading Barcode / QR Code...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Preview
                  if (_scannedImagePath != null)
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(_scannedImagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Result Card
                  if (_result != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _result!.format.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: AppTheme.primary),
                                tooltip: 'Copy Text',
                                onPressed: _copyResult,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _result!.rawValue,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    if (isUrl)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _launchUrl(_result!.rawValue),
                        icon: const Icon(Icons.open_in_browser, color: Colors.white),
                        label: const Text('Open URL in Browser',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Share.share(_result!.rawValue),
                            icon: const Icon(Icons.share, color: AppTheme.primary),
                            label: const Text('Share', style: TextStyle(color: AppTheme.primary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppTheme.secondary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saveAsDocumentNote,
                            icon: const Icon(Icons.bookmark_add_outlined, color: AppTheme.secondary),
                            label: const Text('Save Note', style: TextStyle(color: AppTheme.secondary)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!_isScanning) ...[
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Scan Any QR or Barcode',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Point camera at product barcodes, URLs, Wi-Fi credentials, or text.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _captureFromCamera,
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            label: const Text('Scan Now', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
