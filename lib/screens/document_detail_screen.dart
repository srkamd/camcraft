import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'ocr_result_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final ScannedDocument document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late ScannedDocument _doc;
  final StorageService _storageService = StorageService();
  final PdfService _pdfService = PdfService();
  final ScannerService _scannerService = ScannerService();
  final OcrService _ocrService = OcrService();

  bool _isGeneratingPdf = false;
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _renameDocument() async {
    final controller = TextEditingController(text: _doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != _doc.title) {
      setState(() {
        _doc.title = newTitle;
        _doc.updatedAt = DateTime.now();
      });
      await _storageService.updateDocument(_doc);
    }
  }

  Future<void> _exportPdf({bool shareAfter = false}) async {
    final watermarkController = TextEditingController();
    String? watermark;

    if (!shareAfter) {
      watermark = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: watermarkController,
                decoration: const InputDecoration(
                  labelText: 'Watermark (Optional)',
                  hintText: 'e.g. Confidential, ScanCraft',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('No Watermark'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () => Navigator.pop(context, watermarkController.text.trim()),
              child: const Text('Generate PDF', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfPath = await _pdfService.generatePdf(
        imagePaths: _doc.pagePaths,
        title: _doc.title,
        watermarkText: (watermark != null && watermark.isNotEmpty) ? watermark : null,
      );

      _doc.pdfPath = pdfPath;
      await _storageService.updateDocument(_doc);

      if (shareAfter) {
        await _pdfService.sharePdf(pdfPath);
      } else {
        await _pdfService.openPdf(pdfPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _runOcrOnCurrentPage() async {
    if (_doc.pagePaths.isEmpty) return;
    final pagePath = _doc.pagePaths[_selectedPageIndex];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    final text = await _ocrService.extractText(pagePath);
    if (!mounted) return;
    Navigator.pop(context); // close loader

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultScreen(
          text: text,
          documentTitle: '${_doc.title} - Page ${_selectedPageIndex + 1}',
        ),
      ),
    );
  }

  Future<void> _rotatePage() async {
    if (_doc.pagePaths.isEmpty) return;
    final pagePath = _doc.pagePaths[_selectedPageIndex];

    try {
      final bytes = await File(pagePath).readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original != null) {
        final rotated = img.copyRotate(original, angle: 90);
        await File(pagePath).writeAsBytes(img.encodeJpg(rotated, quality: 95));
        setState(() {}); // Refresh preview
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rotate error: $e')),
      );
    }
  }

  Future<void> _deleteCurrentPage() async {
    if (_doc.pagePaths.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document must have at least one page.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Delete Page ${_selectedPageIndex + 1}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _doc.pagePaths.removeAt(_selectedPageIndex);
        if (_selectedPageIndex >= _doc.pagePaths.length) {
          _selectedPageIndex = _doc.pagePaths.length - 1;
        }
      });
      await _storageService.updateDocument(_doc);
    }
  }

  Future<void> _addMorePages() async {
    final newPaths = await _scannerService.startDocumentScan();
    if (newPaths.isNotEmpty) {
      setState(() {
        _doc.pagePaths.addAll(newPaths);
        _doc.updatedAt = DateTime.now();
      });
      await _storageService.updateDocument(_doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _renameDocument,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _doc.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add Pages',
            onPressed: _addMorePages,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: () => _exportPdf(shareAfter: true),
          ),
        ],
      ),
      body: _isGeneratingPdf
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Generating high-quality PDF...'),
                ],
              ),
            )
          : Column(
              children: [
                // Main Page Preview
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _doc.pagePaths.isNotEmpty
                        ? Image.file(
                            File(_doc.pagePaths[_selectedPageIndex]),
                            fit: BoxFit.contain,
                            key: ValueKey(_doc.pagePaths[_selectedPageIndex] +
                                DateTime.now().millisecondsSinceEpoch.toString()),
                          )
                        : const Center(child: Text('No pages available')),
                  ),
                ),

                // Page Actions Row (Rotate, OCR, Delete)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: _rotatePage,
                        icon: const Icon(Icons.rotate_right, color: AppTheme.primary),
                        label: const Text('Rotate', style: TextStyle(color: AppTheme.primary)),
                      ),
                      TextButton.icon(
                        onPressed: _runOcrOnCurrentPage,
                        icon: const Icon(Icons.text_fields, color: AppTheme.primary),
                        label: const Text('Extract Text (OCR)', style: TextStyle(color: AppTheme.primary)),
                      ),
                      TextButton.icon(
                        onPressed: _deleteCurrentPage,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        label: const Text('Delete Page', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),

                // Thumbnails Carousel
                if (_doc.pagePaths.length > 1)
                  Container(
                    height: 90,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _doc.pagePaths.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedPageIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPageIndex = index),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 65,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              File(_doc.pagePaths[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Bottom Primary Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _exportPdf(shareAfter: false),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                          label: const Text(
                            'View / Export PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
