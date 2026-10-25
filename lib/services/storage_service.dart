import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_document.dart';

class StorageService {
  static const String _documentsKey = 'scancraft_documents';

  /// Retrieve all scanned documents, sorted with latest first
  Future<List<ScannedDocument>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? docsJson = prefs.getString(_documentsKey);
    if (docsJson == null || docsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(docsJson);
      final docs = decoded.map((item) => ScannedDocument.fromMap(item)).toList();
      docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return docs;
    } catch (e) {
      print('StorageService error reading docs: $e');
      return [];
    }
  }

  /// Save a new scanned document
  Future<void> saveDocument(ScannedDocument document) async {
    final docs = await getDocuments();
    docs.insert(0, document);
    await _persist(docs);
  }

  /// Update an existing document (e.g. rename, add/remove pages, update PDF path)
  Future<void> updateDocument(ScannedDocument updatedDoc) async {
    final docs = await getDocuments();
    final index = docs.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      docs[index] = updatedDoc;
      await _persist(docs);
    }
  }

  /// Delete a document by ID
  Future<void> deleteDocument(String id) async {
    final docs = await getDocuments();
    docs.removeWhere((doc) => doc.id == id);
    await _persist(docs);
  }

  /// Persist documents list to SharedPreferences
  Future<void> _persist(List<ScannedDocument> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(docs.map((doc) => doc.toMap()).toList());
    await prefs.setString(_documentsKey, encoded);
  }
}
