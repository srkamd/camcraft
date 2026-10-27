import 'package:test/test.dart';
import 'package:camcraft/models/scanned_document.dart';

void main() {
  group('ScannedDocument Model Unit Tests', () {
    test('Constructor correctly assigns values and calculates getters', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc_123',
        title: 'Tax Invoice 2026',
        pagePaths: ['/path/page1.jpg', '/path/page2.jpg', '/path/page3.jpg'],
        createdAt: now,
        updatedAt: now,
        tag: 'Receipts',
      );

      expect(doc.id, equals('doc_123'));
      expect(doc.title, equals('Tax Invoice 2026'));
      expect(doc.pageCount, equals(3));
      expect(doc.thumbnailPath, equals('/path/page1.jpg'));
      expect(doc.tag, equals('Receipts'));
      expect(doc.pdfPath, isNull);
    });

    test('thumbnailPath returns null when pagePaths is empty', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc_empty',
        title: 'Empty Document',
        pagePaths: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(doc.pageCount, equals(0));
      expect(doc.thumbnailPath, isNull);
    });

    test('Serialization toMap and deserialization fromMap preserves exact data', () {
      final created = DateTime(2026, 10, 25, 14, 30);
      final updated = DateTime(2026, 10, 25, 15, 45);

      final originalDoc = ScannedDocument(
        id: 'doc_serial_01',
        title: 'Identity Card Scan',
        pagePaths: ['/images/front.jpg', '/images/back.jpg'],
        createdAt: created,
        updatedAt: updated,
        tag: 'ID Cards',
        pdfPath: '/pdfs/id_card.pdf',
      );

      final map = originalDoc.toMap();
      final reconstructedDoc = ScannedDocument.fromMap(map);

      expect(reconstructedDoc.id, equals(originalDoc.id));
      expect(reconstructedDoc.title, equals(originalDoc.title));
      expect(reconstructedDoc.pagePaths, equals(originalDoc.pagePaths));
      expect(reconstructedDoc.createdAt, equals(originalDoc.createdAt));
      expect(reconstructedDoc.updatedAt, equals(originalDoc.updatedAt));
      expect(reconstructedDoc.tag, equals(originalDoc.tag));
      expect(reconstructedDoc.pdfPath, equals(originalDoc.pdfPath));
    });

    test('toJson and fromJson string cycle maintains data integrity', () {
      final doc = ScannedDocument(
        id: 'json_test_99',
        title: 'Confidential Agreement',
        pagePaths: ['/storage/p1.png'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tag: 'Docs',
      );

      final jsonString = doc.toJson();
      expect(jsonString, isA<String>());
      expect(jsonString.contains('Confidential Agreement'), isTrue);

      final parsed = ScannedDocument.fromJson(jsonString);
      expect(parsed.id, equals(doc.id));
      expect(parsed.title, equals(doc.title));
      expect(parsed.pagePaths.length, equals(1));
    });
  });
}
