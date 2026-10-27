import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/scanned_document.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'ocr_result_screen.dart';
import 'signature_screen.dart';

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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  /// Show Modern PDF Export Dialog with Compression & Password Protection
  Future<void> _showPdfExportSheet({bool shareDirectly = false}) async {
    final watermarkController = TextEditingController();
    final passwordController = TextEditingController();
    bool enablePassword = false;
    PdfQuality selectedQuality = PdfQuality.standard;

    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: AppTheme.primary, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        shareDirectly ? 'Share PDF Document' : 'PDF Export Options',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quality / Compression Options
                  const Text('File Compression & Quality:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQualityChip(
                        label: 'Standard',
                        subtitle: 'Best Balance',
                        quality: PdfQuality.standard,
                        selected: selectedQuality,
                        onTap: () => setSheetState(() => selectedQuality = PdfQuality.standard),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityChip(
                        label: 'Compact',
                        subtitle: 'Smallest MB',
                        quality: PdfQuality.compact,
                        selected: selectedQuality,
                        onTap: () => setSheetState(() => selectedQuality = PdfQuality.compact),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityChip(
                        label: 'Original',
                        subtitle: 'High Res',
                        quality: PdfQuality.high,
                        selected: selectedQuality,
                        onTap: () => setSheetState(() => selectedQuality = PdfQuality.high),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Watermark Option
                  TextField(
                    controller: watermarkController,
                    decoration: const InputDecoration(
                      labelText: 'Watermark (Optional)',
                      hintText: 'e.g. Confidential, Official, My Name',
                      prefixIcon: Icon(Icons.branding_watermark, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Protection Option
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Password Protection', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Lock PDF with AES encryption', style: TextStyle(fontSize: 12)),
                    value: enablePassword,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) => setSheetState(() => enablePassword = val),
                  ),
                  if (enablePassword)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Set PDF Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Export Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: Icon(shareDirectly ? Icons.share : Icons.file_download_outlined, color: Colors.white),
                      label: Text(
                        shareDirectly ? 'Generate & Share' : 'Generate & Open PDF',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (shouldProceed == true) {
      final watermark = watermarkController.text.trim();
      final password = enablePassword ? passwordController.text.trim() : null;

      setState(() => _isGeneratingPdf = true);
      try {
        final pdfPath = await _pdfService.generatePdf(
          imagePaths: _doc.pagePaths,
          title: _doc.title,
          watermarkText: watermark.isNotEmpty ? watermark : null,
          password: (password != null && password.isNotEmpty) ? password : null,
          quality: selectedQuality,
        );

        _doc.pdfPath = pdfPath;
        await _storageService.updateDocument(_doc);

        if (shareDirectly) {
          await _pdfService.sharePdf(pdfPath);
        } else {
          await _pdfService.openPdf(pdfPath);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Widget _buildQualityChip({
    required String label,
    required String subtitle,
    required PdfQuality quality,
    required PdfQuality selected,
    required VoidCallback onTap,
  }) {
    final isSelected = quality == selected;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? AppTheme.primary : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Launch Signature Screen and stamp onto current page
  Future<void> _openSignatureTool() async {
    if (_doc.pagePaths.isEmpty) return;

    final Uint8List? signaturePng = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );

    if (signaturePng != null && mounted) {
      await _stampSignatureOnCurrentPage(signaturePng);
    }
  }

  Future<void> _stampSignatureOnCurrentPage(Uint8List signatureBytes) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    try {
      final pagePath = _doc.pagePaths[_selectedPageIndex];
      final pageFile = File(pagePath);
      final pageBytes = await pageFile.readAsBytes();

      img.Image? pageImg = img.decodeImage(pageBytes);
      img.Image? signImg = img.decodeImage(signatureBytes);

      if (pageImg != null && signImg != null) {
        // Resize signature to fit cleanly on the bottom right of the page
        final targetSignWidth = (pageImg.width * 0.32).toInt();
        final scaledSign = img.copyResize(signImg, width: targetSignWidth);

        // Place on Bottom Right with margin
        final posX = pageImg.width - scaledSign.width - (pageImg.width * 0.08).toInt();
        final posY = pageImg.height - scaledSign.height - (pageImg.height * 0.08).toInt();

        img.compositeImage(pageImg, scaledSign, dstX: posX, dstY: posY);

        // Overwrite page with signed image
        await pageFile.writeAsBytes(img.encodeJpg(pageImg, quality: 95));

        if (!mounted) return;
        Navigator.pop(context); // close loader
        setState(() {}); // refresh preview

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature stamped successfully onto page!'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error stamping signature: $e')));
      }
    }
  }

  Future<void> _runOcrOnCurrentPage() async {
    if (_doc.pagePaths.isEmpty) return;
    final pagePath = _doc.pagePaths[_selectedPageIndex];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(width: 20),
            Text('Optimizing & Extracting Text...'),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rotate error: $e')));
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
                child: Text(_doc.title, overflow: TextOverflow.ellipsis),
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
            onPressed: () => _showPdfExportSheet(shareDirectly: true),
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
                  Text('Processing & generating PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
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

                // Page Actions Row: Rotate, E-Sign, OCR, Delete
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        icon: Icons.draw_outlined,
                        label: 'E-Sign',
                        onTap: _openSignatureTool,
                      ),
                      _buildActionButton(
                        icon: Icons.rotate_right,
                        label: 'Rotate',
                        onTap: _rotatePage,
                      ),
                      _buildActionButton(
                        icon: Icons.text_fields,
                        label: 'Extract Text',
                        onTap: _runOcrOnCurrentPage,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: Colors.redAccent,
                        onTap: _deleteCurrentPage,
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _showPdfExportSheet(shareDirectly: false),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                          label: const Text(
                            'View / Export PDF',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
