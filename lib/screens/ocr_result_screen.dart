import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

class OcrResultScreen extends StatefulWidget {
  final String text;
  final String documentTitle;

  const OcrResultScreen({
    super.key,
    required this.text,
    required this.documentTitle,
  });

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareText() {
    Share.share(_textController.text, subject: 'Extracted Text from ${widget.documentTitle}');
  }

  Future<void> _exportAsTxt() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.documentTitle}_text.txt');
      await file.writeAsString(_textController.text);
      await Share.shareXFiles([XFile(file.path)], text: 'Exported Text File');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    }
  }

  Future<void> _exportAsWordDoc() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedTitle = widget.documentTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/${sanitizedTitle}.doc');

      final formattedHtml = '''
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset='utf-8'>
<title>${widget.documentTitle}</title>
<style>
body { font-family: 'Calibri', 'Segoe UI', Arial, sans-serif; font-size: 12pt; line-height: 1.6; color: #111827; margin: 40px; }
h1 { font-size: 18pt; color: #10B981; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px; }
p { margin-bottom: 12px; }
</style>
</head>
<body>
<h1>${widget.documentTitle}</h1>
<p>${_textController.text.replaceAll('\n', '<br/>')}</p>
</body>
</html>
''';

      await file.writeAsString(formattedHtml);
      await Share.shareXFiles([XFile(file.path)], text: 'Exported Word Document (.doc)');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Word export error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR - Extracted Text'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: _shareText,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Recognized text will appear here...',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
                    label: const Text('Copy', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _exportAsTxt,
                    icon: const Icon(Icons.description_outlined, size: 18, color: Colors.black87),
                    label: const Text('.TXT', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF2563EB), // Microsoft Blue
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _exportAsWordDoc,
                    icon: const Icon(Icons.article, size: 18, color: Colors.white),
                    label: const Text('Word (.doc)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
