import 'dart:convert';

class ScannedDocument {
  final String id;
  String title;
  List<String> pagePaths;
  final DateTime createdAt;
  DateTime updatedAt;
  String tag;
  String? pdfPath;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.pagePaths,
    required this.createdAt,
    required this.updatedAt,
    this.tag = 'Docs',
    this.pdfPath,
  });

  int get pageCount => pagePaths.length;
  String? get thumbnailPath => pagePaths.isNotEmpty ? pagePaths.first : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pagePaths': pagePaths,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tag': tag,
      'pdfPath': pdfPath,
    };
  }

  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    return ScannedDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      pagePaths: List<String>.from(map['pagePaths'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      tag: map['tag'] as String? ?? 'Docs',
      pdfPath: map['pdfPath'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ScannedDocument.fromJson(String source) =>
      ScannedDocument.fromMap(json.decode(source) as Map<String, dynamic>);
}
