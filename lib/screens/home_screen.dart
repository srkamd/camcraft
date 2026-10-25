import 'package:flutter/material.dart';
import '../models/scanned_document.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/document_card.dart';
import 'document_detail_screen.dart';
import 'id_card_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final ScannerService _scannerService = ScannerService();
  final PdfService _pdfService = PdfService();

  List<ScannedDocument> _allDocuments = [];
  List<ScannedDocument> _filteredDocuments = [];
  bool _isLoading = true;
  String _selectedTag = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tags = ['All', 'Docs', 'ID Cards', 'Notes', 'Receipts'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _importFromGallery() async {
    final pagePaths = await _scannerService.pickFromGallery();
    if (pagePaths.isNotEmpty) {
      final now = DateTime.now();
      final newDoc = ScannedDocument(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Imported ${now.day}-${now.month}',
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

  Future<void> _openIdCardMode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IdCardScannerScreen()),
    );
    _loadDocuments();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  Future<void> _deleteDocument(ScannedDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.document_scanner, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ScanCraft', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                Text('Easy PDF & Doc Scanner', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Import from Gallery',
            onPressed: _importFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'ID Card Mode',
            onPressed: _openIdCardMode,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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

          // Tag Filter Chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = tag == _selectedTag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedTag = tag);
                      _applyFilter();
                    },
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
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
                        child: GridView.builder(
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
                            return DocumentCard(
                              document: doc,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DocumentDetailScreen(document: doc),
                                  ),
                                ).then((_) => _loadDocuments());
                              },
                              onRename: () => _renameDocument(doc),
                              onExportPdf: () => _exportPdf(doc),
                              onDelete: () => _deleteDocument(doc),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startDocumentScan,
        icon: const Icon(Icons.camera_alt),
        label: const Text(
          'Scan Document',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
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
                color: AppTheme.primary.withOpacity(0.08),
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
}
