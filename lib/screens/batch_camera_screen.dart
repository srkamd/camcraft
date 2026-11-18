import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/scanned_document.dart';
import '../services/filter_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'document_detail_screen.dart';

class BatchCameraScreen extends StatefulWidget {
  final ScannedDocument? targetDocument;
  const BatchCameraScreen({super.key, this.targetDocument});

  @override
  State<BatchCameraScreen> createState() => _BatchCameraScreenState();
}

class _BatchCameraScreenState extends State<BatchCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;
  bool _autoMagicColor = true;

  final List<String> _capturedPages = [];
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _showShutterFlash = false;

  @override
  void initState() {
    super.initState();
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

      // Default to back camera
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

      // Restore torch if it was active
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

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
    });

    // Quick white shutter animation
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    try {
      final XFile photo = await _controller!.takePicture();

      // Persist image to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      final fileName = 'batch_page_${DateTime.now().millisecondsSinceEpoch}_${_capturedPages.length + 1}.jpg';
      final savedFile = await File(photo.path).copy(p.join(scansDir.path, fileName));

      setState(() {
        _capturedPages.add(savedFile.path);
      });
    } catch (e) {
      print('Error taking picture: $e');
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

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory(p.join(appDir.path, 'scancraft_images'));
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      for (var f in picked) {
        final fileName = 'batch_gallery_${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}';
        final saved = await File(f.path).copy(p.join(scansDir.path, fileName));
        _capturedPages.add(saved.path);
      }

      setState(() {});
    } catch (e) {
      print('Gallery import in batch error: $e');
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
                            label: const Text('Done & Process', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                                      color: Colors.black.withOpacity(0.65),
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

  Future<void> _finishBatch() async {
    if (_capturedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages captured yet. Tap the capture button to scan pages.')),
      );
      return;
    }

    List<String> finalPages = List.from(_capturedPages);

    // Apply Magic Color automatically if toggled ON
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
    if (_capturedPages.isEmpty) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Scanned Pages?'),
        content: Text('You have captured ${_capturedPages.length} pages. Are you sure you want to discard them?'),
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
      canPop: _capturedPages.isEmpty,
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

            // Document Guide Frame (subtle overlay)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Shutter flash effect
            if (_showShutterFlash)
              Container(
                color: Colors.white.withValues(alpha: 0.65),
              ),

            // Top Control Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _buildGlassCircleButton(
                    icon: Icons.close,
                    onTap: () async {
                      if (_capturedPages.isEmpty) {
                        Navigator.pop(context);
                      } else {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),

                  // Center Pills: Magic Color Toggle & Batch Indicator
                  Row(
                    children: [
                      // Torch Toggle
                      _buildGlassCircleButton(
                        icon: _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                        color: _flashMode == FlashMode.torch ? Colors.amber : Colors.white,
                        onTap: _toggleTorch,
                      ),
                      const SizedBox(width: 8),

                      // Auto Magic Color Pill
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _autoMagicColor = !_autoMagicColor;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                'Magic Color ${_autoMagicColor ? 'ON' : 'OFF'}',
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

                  // Switch Camera
                  if (_cameras.length > 1)
                    _buildGlassCircleButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _switchCamera,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Continuous Batch Info Strip
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _flashMode == FlashMode.torch
                            ? 'Torch Locked ON • Flip pages and tap shutter'
                            : 'Continuous Batch Scan • Ready to shoot',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Shutter & Thumbnail Controls
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Import from Gallery Button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: const Icon(Icons.photo_library, color: Colors.white, size: 24),
                    ),
                  ),

                  // Center: Huge Tactile Shutter Button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isCapturing ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
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

                  // Right: Scanned Thumbnail Tray with Count Badge & Done Action
                  _capturedPages.isNotEmpty
                      ? GestureDetector(
                          onTap: _showScannedPagesPreview,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Last Scanned Image Thumbnail Box
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primary, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.file(
                                  File(_capturedPages.last),
                                  fit: BoxFit.cover,
                                ),
                              ),

                              // Page Count Badge (Green Pill)
                              Positioned(
                                top: -8,
                                right: -8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${_capturedPages.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12, width: 1.5),
                          ),
                          child: const Center(
                            child: Text(
                              '0',
                              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Persistent Floating "Done (N)" Pill Button when pages > 0
            if (_capturedPages.isNotEmpty)
              Positioned(
                bottom: 120,
                right: 20,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    'Done (${_capturedPages.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _finishBatch,
                ),
              ),
          ],
        ),
      ),
    );
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
