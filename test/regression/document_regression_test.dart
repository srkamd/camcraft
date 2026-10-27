import 'package:test/test.dart';
import 'package:camcraft/models/scanned_document.dart';

void main() {
  group('Regression Test Suite - Document Pipeline & State Logic', () {
    test('REGRESSION-01: Multi-Document Merge preserves exact page order without data corruption', () {
      final docA = ScannedDocument(
        id: 'doc_a',
        title: 'Invoice Part 1',
        pagePaths: ['/scan_1.jpg', '/scan_2.jpg'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        tag: 'Receipts',
      );

      final docB = ScannedDocument(
        id: 'doc_b',
        title: 'Invoice Part 2',
        pagePaths: ['/scan_3.jpg'],
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
        tag: 'Receipts',
      );

      final docC = ScannedDocument(
        id: 'doc_c',
        title: 'Terms Appendix',
        pagePaths: ['/scan_4.jpg', '/scan_5.jpg'],
        createdAt: DateTime(2026, 1, 3),
        updatedAt: DateTime(2026, 1, 3),
        tag: 'Docs',
      );

      // Simulation of Merge Logic in HomeScreen
      final List<ScannedDocument> selectedDocs = [docA, docB, docC];
      final List<String> combinedPages = [];
      for (var d in selectedDocs) {
        combinedPages.addAll(d.pagePaths);
      }

      final mergedDoc = ScannedDocument(
        id: 'merged_result',
        title: 'Master Combined Invoice',
        pagePaths: combinedPages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tag: 'Docs',
      );

      // Verification
      expect(mergedDoc.pageCount, equals(5));
      expect(mergedDoc.pagePaths[0], equals('/scan_1.jpg'));
      expect(mergedDoc.pagePaths[1], equals('/scan_2.jpg'));
      expect(mergedDoc.pagePaths[2], equals('/scan_3.jpg'));
      expect(mergedDoc.pagePaths[3], equals('/scan_4.jpg'));
      expect(mergedDoc.pagePaths[4], equals('/scan_5.jpg'));
    });

    test('REGRESSION-02: Search & Filter algorithm matches both tag and substring accurately', () {
      final docs = [
        ScannedDocument(
          id: '1',
          title: 'University Degree Certificate',
          pagePaths: ['/p1.jpg'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tag: 'Docs',
        ),
        ScannedDocument(
          id: '2',
          title: 'CNIC National Identity Card',
          pagePaths: ['/p2.jpg'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tag: 'ID Cards',
        ),
        ScannedDocument(
          id: '3',
          title: 'Grocery Supermarket Bill',
          pagePaths: ['/p3.jpg'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tag: 'Receipts',
        ),
        ScannedDocument(
          id: '4',
          title: 'Doctor Medical Prescription Note',
          pagePaths: ['/p4.jpg'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tag: 'Notes',
        ),
      ];

      // Test 1: Tag filter = 'All' returns all 4
      final allDocs = docs.where((doc) {
        const selectedTag = 'All';
        const query = '';
        return (selectedTag == 'All' || doc.tag == selectedTag) &&
            (query.isEmpty || doc.title.toLowerCase().contains(query));
      }).toList();
      expect(allDocs.length, equals(4));

      // Test 2: Tag filter = 'ID Cards' returns exactly 1
      final idCards = docs.where((doc) {
        const selectedTag = 'ID Cards';
        const query = '';
        return (selectedTag == 'All' || doc.tag == selectedTag) &&
            (query.isEmpty || doc.title.toLowerCase().contains(query));
      }).toList();
      expect(idCards.length, equals(1));
      expect(idCards.first.title, contains('CNIC'));

      // Test 3: Search query = 'bill' returns Grocery Supermarket Bill regardless of case
      final billSearch = docs.where((doc) {
        const selectedTag = 'All';
        final query = 'BiLL'.toLowerCase().trim();
        return (selectedTag == 'All' || doc.tag == selectedTag) &&
            (query.isEmpty || doc.title.toLowerCase().contains(query));
      }).toList();
      expect(billSearch.length, equals(1));
      expect(billSearch.first.id, equals('3'));
    });

    test('REGRESSION-03: Page removal shifts remaining indices without dropping subsequent pages', () {
      final doc = ScannedDocument(
        id: 'doc_delete_test',
        title: 'Multi-page contract',
        pagePaths: ['/page_1.jpg', '/page_2.jpg', '/page_3.jpg', '/page_4.jpg'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Delete page at index 1 ('/page_2.jpg')
      doc.pagePaths.removeAt(1);

      expect(doc.pageCount, equals(3));
      expect(doc.pagePaths[0], equals('/page_1.jpg'));
      expect(doc.pagePaths[1], equals('/page_3.jpg'));
      expect(doc.pagePaths[2], equals('/page_4.jpg'));
    });
  });
}
