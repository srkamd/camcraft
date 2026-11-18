import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/scanned_document.dart';
import '../services/filter_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'document_detail_screen.dart';
import 'ocr_result_screen.dart';

enum CameraScanMode {
  idCard,
  single,
  batch,
  ocr,
}

class BatchCameraScreen extends StatefulWidget {
  final CameraScanMode initialMode;
  final ScannedDocument? targetDocument;

  const BatchCameraScreen({
    super.key,
    this.initialMode = CameraScanMode.batch,
    this.targetDocument,
  });

  @override
  State<BatchCameraScreen> createState() => _BatchCameraScreenState();
}

class _BatchCameraScreenState extends State<BatchCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;

  late CameraScanMode _currentMode;
  FlashMode _flashMode = FlashMode.off;
  bool _autoMagicColor = true;
  bool _showGrid = false;
  bool _showShutterFlash = false;

  // Batch Mode Pages
  final List<String> _capturedPages = [];

  // ID Card Mode State
  String? _idCardFrontPath;
  String? _idCardBackPath;
  bool _isIdCardFront = true;

  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera available on this device.')),
        );
        Navigator.pop(context);
        return;
      }

      final backIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _selectedCameraIndex = backIndex != -1 ? backIndex : 0;
      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (!mounted) return;

      // Maintain persistent torch if user activated it
      if (_flashMode == FlashMode.torch) {
        await newController.setFlashMode(FlashMode.torch);
      } else {
        await newController.setFlashMode(FlashMode.off);
      }

      setState(() {
        _controller = newController;
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera controller: $e');
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      await _controller!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      print('Error toggling torch: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<String> _saveCapturedFile(XFile photo, String prefix) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }

    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destination = p.join(scansDir.path, fileName);
    final savedFile = await File(photo.path).copy(destination);
    return savedFile.path;
  }

  /// Main Shutter Tap Handler
  Future<void> _onShutterTap() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
    });

    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    try {
      final XFile photo = await _controller!.takePicture();

      switch (_currentMode) {
        case CameraScanMode.batch:
          await _handleBatchCapture(photo);
          break;
        case CameraScanMode.single:
          await _handleSingleCapture(photo);
          break;
        case CameraScanMode.idCard:
          await _handleIdCardCapture(photo);
          break;
        case CameraScanMode.ocr:
          await _handleOcrCapture(photo);
          break;
      }
    } catch (e) {
      print('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  /// Batch Scan Mode Logic: Stays in camera, appends to corner thumbnail stack
  Future<void> _handleBatchCapture(XFile photo) async {
    final savedPath = await _saveCapturedFile(photo, 'batch_page_${_capturedPages.length + 1}');
    setState(() {
      _capturedPages.add(savedPath);
    });
  }

  /// Single Scan Mode Logic: Captures 1 page and immediately opens document
  Future<void> _handleSingleCapture(XFile photo) async {
    final savedPath = await _saveCapturedFile(photo, 'single_scan');
    String finalPath = savedPath;

    if (_autoMagicColor) {
      final enhanced = await FilterService.applyFilter(
        imagePath: savedPath,
        filterType: DocumentFilterType.magicColor,
      );
      finalPath = enhanced;
    }

    if (widget.targetDocument != null) {
      widget.targetDocument!.pagePaths.add(finalPath);
      widget.targetDocument!.updatedAt = DateTime.now();
      await _storageService.updateDocument(widget.targetDocument!);
      if (!mounted) return;
      Navigator.pop(context, [finalPath]);
      return;
    }

    final now = DateTime.now();
    final doc = ScannedDocument(
      id: now.millisecondsSinceEpoch.toString(),
      title: 'Scan ${now.day}-${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      pagePaths: [finalPath],
      createdAt: now,
      updatedAt: now,
      tag: 'Docs',
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

  /// ID Card Mode Logic: Guides front then back, then stitches onto A4 page
  Future<void> _handleIdCardCapture(XFile photo) async {
    if (_isIdCardFront) {
      final savedPath = await _saveCapturedFile(photo, 'id_front');
      setState(() {
        _idCardFrontPath = savedPath;
        _isIdCardFront = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Front side saved! Now flip and align the BACK side of ID card.'),
            duration: Duration(seconds: 3),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final savedPath = await _saveCapturedFile(photo, 'id_back');
      _idCardBackPath = savedPath;
      await _stitchIdCard();
    }
  }

  Future<void> _stitchIdCard() async {
    if (_idCardFrontPath == null || _idCardBackPath == null) return;

    // Show stitching dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Stitching ID Card to 2-in-1 A4 Page...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final frontBytes = await File(_idCardFrontPath!).readAsBytes();
      final backBytes = await File(_idCardBackPath!).readAsBytes();

      img.Image? frontImg = img.decodeImage(frontBytes);
      img.Image? backImg = img.decodeImage(backBytes);

      if (frontImg != null && backImg != null) {
        const canvasWidth = 1240;
        const canvasHeight = 1754;
        final canvas = img.Image(width: canvasWidth, height: canvasHeight);
        img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

        const targetWidth = 1000;
        final scaledFront = img.copyResize(frontImg, width: targetWidth);
        final scaledBack = img.copyResize(backImg, width: targetWidth);

        final frontX = (canvasWidth - scaledFront.width) ~/ 2;
        const frontY = 140;
        img.compositeImage(canvas, scaledFront, dstX: frontX, dstY: frontY);

        final backX = (canvasWidth - scaledBack.width) ~/ 2;
        const backY = 900;
        img.compositeImage(canvas, scaledBack, dstX: backX, dstY: backY);

        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
        if (!await scansDir.exists()) await scansDir.create(recursive: true);

        final outputPath = p.join(
          scansDir.path,
          'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final jpgBytes = img.encodeJpg(canvas, quality: 90);
        await File(outputPath).writeAsBytes(jpgBytes);

        String finalPath = outputPath;
        if (_autoMagicColor) {
          finalPath = await FilterService.applyFilter(
            imagePath: outputPath,
            filterType: DocumentFilterType.magicColor,
          );
        }

        final now = DateTime.now();
        final doc = ScannedDocument(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'ID Card ${now.day}-${now.month}',
          pagePaths: [finalPath],
          createdAt: now,
          updatedAt: now,
          tag: 'ID Cards',
        );

        await _storageService.saveDocument(doc);

        if (!mounted) return;
        Navigator.pop(context); // Close dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: doc),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('ID stitch error: $e');
    }
  }

  /// OCR Mode Logic: Captures 1 page and opens OCR Text Result
  Future<void> _handleOcrCapture(XFile photo) async {
    final savedPath = await _saveCapturedFile(photo, 'ocr_source');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Recognizing text with OCR...',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final extractedText = await _ocrService.extractText(savedPath);

    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultScreen(
          text: extractedText,
          documentTitle: 'OCR Scan ${DateTime.now().day}/${DateTime.now().month}',
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      if (_currentMode == CameraScanMode.batch) {
        final List<XFile> picked = await _picker.pickMultiImage();
        if (picked.isEmpty) return;

        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
        if (!await scansDir.exists()) await scansDir.create(recursive: true);

        for (var f in picked) {
          final fileName = 'batch_gallery_${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}';
          final saved = await File(f.path).copy(p.join(scansDir.path, fileName));
          _capturedPages.add(saved.path);
        }
        setState(() {});
      } else {
        final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        if (_currentMode == CameraScanMode.single) {
          await _handleSingleCapture(picked);
        } else if (_currentMode == CameraScanMode.ocr) {
          await _handleOcrCapture(picked);
        }
      }
    } catch (e) {
      print('Gallery import error: $e');
    }
  }

  void _showScannedPagesPreview() {
    if (_capturedPages.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Captured Pages (${_capturedPages.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.check, color: AppTheme.primary),
                            label: const Text(
                              'Done & Process',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _finishBatch();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _capturedPages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(_capturedPages[index]),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setSheetState(() {
                                        _capturedPages.removeAt(index);
                                      });
                                      setState(() {});
                                      if (_capturedPages.isEmpty) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Completes batch scanning when user taps "Done"
  Future<void> _finishBatch() async {
    if (_capturedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages captured yet. Tap the capture button to scan pages.')),
      );
      return;
    }

    List<String> finalPages = List.from(_capturedPages);

    if (_autoMagicColor) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Enhancing ${finalPages.length} pages with Magic Color...',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      finalPages = await FilterService.applyFilterToBatch(
        imagePaths: finalPages,
        filterType: DocumentFilterType.magicColor,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog
    }

    if (widget.targetDocument != null) {
      widget.targetDocument!.pagePaths.addAll(finalPages);
      widget.targetDocument!.updatedAt = DateTime.now();
      await _storageService.updateDocument(widget.targetDocument!);
      if (!mounted) return;
      Navigator.pop(context, finalPages);
      return;
    }

    final now = DateTime.now();
    final newDoc = ScannedDocument(
      id: now.millisecondsSinceEpoch.toString(),
      title: 'Batch Scan (${finalPages.length} pages) ${now.day}-${now.month}',
      pagePaths: finalPages,
      createdAt: now,
      updatedAt: now,
      tag: 'Docs',
    );

    await _storageService.saveDocument(newDoc);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentDetailScreen(document: newDoc),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_capturedPages.isEmpty && (_idCardFrontPath == null)) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Scanned Work?'),
        content: Text(
          _currentMode == CameraScanMode.batch
              ? 'You have ${_capturedPages.length} pages scanned. Discard them?'
              : 'Discard current scanned photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Scanning'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return PopScope(
      canPop: _capturedPages.isEmpty && _idCardFrontPath == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Live Fullscreen Camera Preview
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),

            // Optional 3x3 Grid Overlay
            if (_showGrid) _buildGridOverlay(),

            // Mode-specific Viewfinder Guides
            _buildViewfinderGuide(),

            // Shutter Flash Animation Effect
            if (_showShutterFlash)
              Container(
                color: Colors.white.withValues(alpha: 0.65),
              ),

            // Top Control Bar (Close, Torch, Magic Color, Grid, Flip)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassCircleButton(
                    icon: Icons.close,
                    onTap: () async {
                      final shouldPop = await _onWillPop();
                      if (shouldPop && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Row(
                    children: [
                      // Torch Toggle (Persistent Lock)
                      _buildGlassCircleButton(
                        icon: _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                        color: _flashMode == FlashMode.torch ? Colors.amber : Colors.white,
                        onTap: _toggleTorch,
                      ),
                      const SizedBox(width: 8),

                      // Grid lines toggle
                      _buildGlassCircleButton(
                        icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                        color: _showGrid ? AppTheme.primary : Colors.white,
                        onTap: () => setState(() => _showGrid = !_showGrid),
                      ),
                      const SizedBox(width: 8),

                      // Magic Color Toggle Pill
                      GestureDetector(
                        onTap: () => setState(() => _autoMagicColor = !_autoMagicColor),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: _autoMagicColor
                                ? AppTheme.primary.withValues(alpha: 0.85)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _autoMagicColor ? Colors.transparent : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_fix_high,
                                size: 14,
                                color: _autoMagicColor ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _autoMagicColor ? 'Magic Color' : 'Original',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Camera Flip
                  if (_cameras.length > 1)
                    _buildGlassCircleButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _switchCamera,
                    )
                  else
                    const SizedBox(width: 42),
                ],
              ),
            ),

            // Top Status / Guide Pill
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 20,
              right: 20,
              child: Center(child: _buildTopGuidePill()),
            ),

            // Bottom Control Container (CamScanner Style: Modes Above Shutter)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 14, bottom: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CamScanner Horizontal Mode Selector Bar
                    _buildModeSelectorBar(),
                    const SizedBox(height: 18),

                    // Shutter Row: Gallery | Big Shutter | Thumbnail Stack & Done
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left: Gallery Import Button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1.5),
                              ),
                              child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
                            ),
                          ),

                          // Center: CamScanner Tactile Circular Shutter Button
                          GestureDetector(
                            onTap: _onShutterTap,
                            child: Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isCapturing
                                      ? AppTheme.primary.withValues(alpha: 0.6)
                                      : (_currentMode == CameraScanMode.idCard
                                          ? const Color(0xFF0284C7)
                                          : AppTheme.primary),
                                  shape: BoxShape.circle,
                                ),
                                child: _isCapturing
                                    ? const Center(
                                        child: SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),

                          // Right: Batch Corner Thumbnail Stack with Live Counter & Done Action
                          _buildRightActionSlot(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Viewfinder Guidelines per mode
  Widget _buildViewfinderGuide() {
    if (_currentMode == CameraScanMode.idCard) {
      return Center(
        child: Container(
          width: 320,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF0284C7), width: 2.5),
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 38,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 8),
              Text(
                _isIdCardFront ? 'Align ID Card Front Here' : 'Align ID Card Back Here',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // CamScanner-style sleek corner brackets for Batch / Single / OCR
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 110),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              // 4 Corner Brackets
              Positioned(top: 0, left: 0, child: _cornerBracket(isTop: true, isLeft: true)),
              Positioned(top: 0, right: 0, child: _cornerBracket(isTop: true, isLeft: false)),
              Positioned(bottom: 0, left: 0, child: _cornerBracket(isTop: false, isLeft: true)),
              Positioned(bottom: 0, right: 0, child: _cornerBracket(isTop: false, isLeft: false)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerBracket({required bool isTop, required bool isLeft}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: AppTheme.primary, width: 3.5) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: AppTheme.primary, width: 3.5) : BorderSide.none,
          left: isLeft ? const BorderSide(color: AppTheme.primary, width: 3.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: AppTheme.primary, width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }

  /// 3x3 Grid Overlay
  Widget _buildGridOverlay() {
    return IgnorePointer(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Informational Top Guide Pill
  Widget _buildTopGuidePill() {
    String text;
    IconData icon;
    Color iconColor;

    switch (_currentMode) {
      case CameraScanMode.batch:
        if (_capturedPages.isEmpty) {
          text = 'Batch Scan • Flip pages and tap shutter continuously';
          icon = Icons.filter_none;
          iconColor = const Color(0xFF10B981);
        } else {
          text = '${_capturedPages.length} pages captured • Tap "Done" when finished';
          icon = Icons.check_circle_outline;
          iconColor = AppTheme.primary;
        }
        break;
      case CameraScanMode.single:
        text = 'Single Scan • 1 photo will create document';
        icon = Icons.camera_alt;
        iconColor = Colors.white;
        break;
      case CameraScanMode.idCard:
        text = _isIdCardFront ? 'Step 1/2: Scan ID Front' : 'Step 2/2: Scan ID Back';
        icon = Icons.badge_outlined;
        iconColor = const Color(0xFF0284C7);
        break;
      case CameraScanMode.ocr:
        text = 'OCR Mode • Captures and extracts editable text';
        icon = Icons.text_fields;
        iconColor = const Color(0xFF8B5CF6);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// CamScanner Mode Switcher Bar above Shutter
  Widget _buildModeSelectorBar() {
    final modes = [
      (CameraScanMode.idCard, 'ID CARD'),
      (CameraScanMode.single, 'SINGLE'),
      (CameraScanMode.batch, 'BATCH'),
      (CameraScanMode.ocr, 'OCR'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((m) {
          final isSelected = _currentMode == m.$1;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentMode = m.$1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withValues(alpha: 0.25) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                m.$2,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Right slot next to shutter:
  /// In Batch mode -> Corner Thumbnail Stack + "Done" Button
  /// In other modes -> Reset or placeholder
  Widget _buildRightActionSlot() {
    if (_currentMode == CameraScanMode.batch) {
      if (_capturedPages.isNotEmpty) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail Stack with Counter Badge
            GestureDetector(
              onTap: _showScannedPagesPreview,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(_capturedPages.last),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_capturedPages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // CamScanner Signature "Done (N) →" Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
              onPressed: _finishBatch,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Done (${_capturedPages.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
          child: const Center(
            child: Text(
              '0',
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } else if (_currentMode == CameraScanMode.idCard && !_isIdCardFront) {
      // ID Card mode: restart front side button if needed
      return TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Colors.amber),
        onPressed: () {
          setState(() {
            _idCardFrontPath = null;
            _idCardBackPath = null;
            _isIdCardFront = true;
          });
        },
        icon: const Icon(Icons.restart_alt, size: 16),
        label: const Text('Reset', style: TextStyle(fontSize: 12)),
      );
    }

    return const SizedBox(width: 50, height: 50);
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
