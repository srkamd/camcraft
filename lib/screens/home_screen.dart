import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_document.dart';
import '../services/filter_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/document_card.dart';
import 'batch_camera_screen.dart';
import 'document_detail_screen.dart';
import 'id_card_scanner_screen.dart';
import 'qr_scanner_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final ScannerService _scannerService = ScannerService();
  final PdfService _pdfService = PdfService();
  final SecurityService _securityService = SecurityService();

  List<ScannedDocument> _allDocuments = [];
  List<ScannedDocument> _filteredDocuments = [];
  bool _isLoading = true;
  bool _isLocked = false;
  bool _isAppLockEnabled = false;

  // Selection & Merge Mode
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  // View Mode & Speed-Dial FAB
  bool _isGridView = false;
  bool _isFabExpanded = false;

  String _selectedTag = 'All';
  final TextEditingController _searchController = TextEditingController();
  final List<String> _tags = ['All', 'Docs', 'ID Cards', 'Notes', 'Receipts'];

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _checkAppLock();
    _loadDocuments();
    _searchController.addListener(_applyFilter);
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isGridView = prefs.getBool('is_grid_view') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _toggleViewMode() async {
    final next = !_isGridView;
    setState(() => _isGridView = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_grid_view', next);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAppLock() async {
    final enabled = await _securityService.isAppLockEnabled();
    setState(() {
      _isAppLockEnabled = enabled;
      _isLocked = enabled;
    });

    if (enabled) {
      final authenticated = await _securityService.authenticate();
      if (authenticated) {
        setState(() => _isLocked = false);
      }
    }
  }

  Future<void> _toggleAppLock() async {
    final isAvailable = await _securityService.isBiometricsAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric / Fingerprint sensor not available on this device')),
      );
      return;
    }

    final authenticated = await _securityService.authenticate();
    if (authenticated) {
      final newState = !_isAppLockEnabled;
      await _securityService.setAppLockEnabled(newState);
      setState(() => _isAppLockEnabled = newState);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'App Lock (Biometrics) Enabled!' : 'App Lock Disabled'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await _storageService.getDocuments();
    setState(() {
      _allDocuments = docs;
      _isLoading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocuments = _allDocuments.where((doc) {
        final matchesTag = _selectedTag == 'All' || doc.tag == _selectedTag;
        final matchesQuery = query.isEmpty || doc.title.toLowerCase().contains(query);
        return matchesTag && matchesQuery;
      }).toList();
    });
  }

  Future<void> _startDocumentScan() async {
    final pagePaths = await _scannerService.startDocumentScan();
    if (pagePaths.isNotEmpty) {
      final now = DateTime.now();
      final newDoc = ScannedDocument(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Document ${now.day}-${now.month} ${now.hour}:${now.minute}',
        pagePaths: pagePaths,
        createdAt: now,
        updatedAt: now,
        tag: 'Docs',
      );

      await _storageService.saveDocument(newDoc);
      await _loadDocuments();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentDetailScreen(document: newDoc),
        ),
      ).then((_) => _loadDocuments());
    }
  }

  /// Continuous Batch Scan Mode:
  /// Keeps camera live, persists torch/flash across multiple scans, adds captured pages
  /// to a floating thumbnail tray with live counter badge, and processes all pages together.
  Future<void> _startBatchScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BatchCameraScreen(),
      ),
    );
    _loadDocuments();
  }

  /// Import photos from gallery with automatic Magic Color enhancement
  Future<void> _importFromGallery() async {
    final pagePaths = await _scannerService.pickFromGallery();
    if (pagePaths.isNotEmpty) {
      if (!mounted) return;
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
                    'Auto-enhancing images with Magic Color...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final enhancedPaths = await FilterService.applyFilterToBatch(
        imagePaths: pagePaths,
        filterType: DocumentFilterType.magicColor,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      final now = DateTime.now();
      final newDoc = ScannedDocument(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Imported (${enhancedPaths.length} pages) ${now.day}-${now.month}',
        pagePaths: enhancedPaths,
        createdAt: now,
        updatedAt: now,
        tag: 'Docs',
      );

      await _storageService.saveDocument(newDoc);
      await _loadDocuments();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentDetailScreen(document: newDoc),
        ),
      ).then((_) => _loadDocuments());
    }
  }

  Future<void> _openIdCardMode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IdCardScannerScreen()),
    );
    _loadDocuments();
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  /// Multi-document Merge Operation
  Future<void> _mergeSelectedDocuments() async {
    if (_selectedDocIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 documents to merge.')),
      );
      return;
    }

    final titleController = TextEditingController(text: 'Merged Document ${DateTime.now().day}/${DateTime.now().month}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Documents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merge ${_selectedDocIds.length} selected documents into one single master document?'),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Merged Document Title'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final selectedDocs = _allDocuments.where((d) => _selectedDocIds.contains(d.id)).toList();
      List<String> combinedPages = [];
      for (var d in selectedDocs) {
        combinedPages.addAll(d.pagePaths);
      }

      final now = DateTime.now();
      final mergedDoc = ScannedDocument(
        id: now.millisecondsSinceEpoch.toString(),
        title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Merged Document',
        pagePaths: combinedPages,
        createdAt: now,
        updatedAt: now,
        tag: 'Docs',
      );

      await _storageService.saveDocument(mergedDoc);

      setState(() {
        _isSelectionMode = false;
        _selectedDocIds.clear();
      });

      await _loadDocuments();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully merged ${selectedDocs.length} documents!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentDetailScreen(document: mergedDoc),
        ),
      );
    }
  }

  Future<void> _renameDocument(ScannedDocument doc) async {
    final controller = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
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

    if (newTitle != null && newTitle.isNotEmpty) {
      doc.title = newTitle;
      doc.updatedAt = DateTime.now();
      await _storageService.updateDocument(doc);
      _loadDocuments();
    }
  }

  Future<void> _exportPdf(ScannedDocument doc) async {
    try {
      final pdfPath = await _pdfService.generatePdf(
        imagePaths: doc.pagePaths,
        title: doc.title,
      );
      doc.pdfPath = pdfPath;
      await _storageService.updateDocument(doc);
      await _pdfService.openPdf(pdfPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }

  Future<void> _deleteDocument(ScannedDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
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
      await _storageService.deleteDocument(doc.id);
      _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, size: 64, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              const Text('CamCraft is Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Use fingerprint or face recognition to unlock', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _checkAppLock,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text('Unlock with Biometrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedDocIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold))
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/icons/camcraft_logo_512.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CamCraft', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      Text('Smart ML PDF & Doc Scanner', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedDocIds.clear();
                  }),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'QR / Barcode Scanner',
                  onPressed: _openQrScanner,
                ),
                IconButton(
                  icon: const Icon(Icons.badge_outlined),
                  tooltip: 'ID Card Mode',
                  onPressed: _openIdCardMode,
                ),
                IconButton(
                  icon: Icon(_isAppLockEnabled ? Icons.lock : Icons.lock_open,
                      color: _isAppLockEnabled ? AppTheme.primary : Colors.grey),
                  tooltip: 'Toggle App Lock',
                  onPressed: _toggleAppLock,
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'About CamCraft',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search documents by title...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),

          // Quick Action Dashboard Bar (Scan, ID Card, Gallery, QR)
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.08),
                      AppTheme.accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionBtn(
                      icon: Icons.camera_alt,
                      label: 'Single Scan',
                      onTap: _startDocumentScan,
                      color: AppTheme.primary,
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.filter_none,
                      label: 'Batch Scan',
                      onTap: _startBatchScan,
                      color: const Color(0xFF10B981),
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.badge_outlined,
                      label: 'ID Card',
                      onTap: _openIdCardMode,
                      color: const Color(0xFF0284C7),
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.photo_library_outlined,
                      label: 'Import',
                      onTap: _importFromGallery,
                      color: const Color(0xFFD97706),
                    ),
                    _buildQuickActionBtn(
                      icon: Icons.qr_code_scanner,
                      label: 'QR Scanner',
                      onTap: _openQrScanner,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
            ),

          // Tag Filter Chips & Multi-select trigger
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tags.length,
                        itemBuilder: (context, index) {
                          final tag = _tags[index];
                          final isSelected = tag == _selectedTag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedTag = tag);
                                _applyFilter();
                              },
                              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                              checkmarkColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.primary : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_filteredDocuments.length > 1)
                    IconButton(
                      icon: const Icon(Icons.checklist, size: 22, color: AppTheme.primary),
                      tooltip: 'Select & Merge',
                      onPressed: () => setState(() => _isSelectionMode = true),
                    ),
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 22, color: Colors.grey.shade700),
                    tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
                    onPressed: _toggleViewMode,
                  ),
                ],
              ),
            ),

          // Documents List / Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredDocuments.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadDocuments,
                        color: AppTheme.primary,
                        child: _isGridView ? _buildGridView() : _buildListView(),
                      ),
          ),

          // Merge Bar when in Selection Mode
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selectedDocIds.length >= 2 ? _mergeSelectedDocuments : null,
                      icon: const Icon(Icons.merge_type, color: Colors.white),
                      label: Text(
                        'Merge Selected (${_selectedDocIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isFabExpanded) ...[
                  _buildFabActionItem(
                    label: 'Batch Scan',
                    icon: Icons.filter_none,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      setState(() => _isFabExpanded = false);
                      _startBatchScan();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabActionItem(
                    label: 'ID Card Mode',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      setState(() => _isFabExpanded = false);
                      _openIdCardMode();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabActionItem(
                    label: 'Import Photos',
                    icon: Icons.photo_library,
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      setState(() => _isFabExpanded = false);
                      _importFromGallery();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabActionItem(
                    label: 'Single Scan',
                    icon: Icons.camera_alt,
                    color: AppTheme.primary,
                    onTap: () {
                      setState(() => _isFabExpanded = false);
                      _startDocumentScan();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                FloatingActionButton(
                  heroTag: 'main_fab',
                  backgroundColor: _isFabExpanded ? Colors.grey.shade800 : AppTheme.primary,
                  elevation: 6,
                  onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.375 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isFabExpanded ? Icons.close : Icons.camera_alt,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFabActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        final isSelected = _selectedDocIds.contains(doc.id);

        return Stack(
          children: [
            DocumentCard(
              document: doc,
              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedDocIds.remove(doc.id);
                    } else {
                      _selectedDocIds.add(doc.id);
                    }
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentDetailScreen(document: doc),
                    ),
                  ).then((_) => _loadDocuments());
                }
              },
              onRename: () => _renameDocument(doc),
              onExportPdf: () => _exportPdf(doc),
              onDelete: () => _deleteDocument(doc),
            ),
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white70,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                    ],
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 26,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filteredDocuments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        final isSelected = _selectedDocIds.contains(doc.id);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedDocIds.remove(doc.id);
                } else {
                  _selectedDocIds.add(doc.id);
                }
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentDetailScreen(document: doc),
                ),
              ).then((_) => _loadDocuments());
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail with page count badge
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        width: 58,
                        height: 72,
                        color: Colors.grey.shade100,
                        child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
                            ? Image.file(
                                File(doc.thumbnailPath!),
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(Icons.picture_as_pdf, color: Colors.grey, size: 28),
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${doc.pageCount}p',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Info (Title, Tag, Date)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc.tag,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${doc.createdAt.day}/${doc.createdAt.month}/${doc.createdAt.year}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions or Selection check
                if (_isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                        tooltip: 'Share PDF',
                        onPressed: () => _exportPdf(doc),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'rename') _renameDocument(doc);
                          if (val == 'delete') _deleteDocument(doc);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text('Rename')]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_outlined, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Documents Scanned Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to scan your first document, notes, ID Card, or receipt with automatic edge detection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _importFromGallery,
              icon: const Icon(Icons.photo_library, color: AppTheme.primary),
              label: const Text('Import from Photos', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
