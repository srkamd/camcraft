import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from a scanned image path with intelligent pre-processing
  Future<String> extractText(String imagePath) async {
    File? tempPreprocessedFile;
    try {
      final originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        return 'Error: Document image file not found.';
      }

      // Step 1: Intelligent Pre-Processing for Maximum OCR Accuracy
      tempPreprocessedFile = await _preprocessForOcr(originalFile);
      final inputImage = InputImage.fromFile(tempPreprocessedFile ?? originalFile);

      // Step 2: Run ML Kit Text Recognition
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Step 3: Clean & format extracted text
      if (recognizedText.text.trim().isEmpty) {
        // Fallback: Try with original image if preprocessed produced nothing
        if (tempPreprocessedFile != null) {
          final fallbackResult = await _textRecognizer.processImage(InputImage.fromFile(originalFile));
          if (fallbackResult.text.trim().isNotEmpty) {
            return _formatRecognizedText(fallbackResult);
          }
        }
        return 'No readable text was detected in this document.\nTip: Ensure good lighting and that text is clearly visible.';
      }

      return _formatRecognizedText(recognizedText);
    } catch (e) {
      print('OCR extraction error: $e');
      return 'Failed to extract text: $e';
    } finally {
      // Clean up temporary preprocessed file
      if (tempPreprocessedFile != null && await tempPreprocessedFile.exists()) {
        try {
          await tempPreprocessedFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Grayscale, contrast stretch, and sharpen to make text pop out
  Future<File?> _preprocessForOcr(File file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // 1. Resize if image is oversized (keeps processing fast and clean)
      if (decoded.width > 2200 || decoded.height > 2200) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? 2200 : null,
          height: decoded.height >= decoded.width ? 2200 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // 2. Convert to Grayscale (removes color noise & yellow page tint)
      decoded = img.grayscale(decoded);

      // 3. Boost contrast and brightness so text is dark and background is light
      decoded = img.adjustColor(
        decoded,
        contrast: 1.5,
        brightness: 1.08,
      );

      // Save to temporary cache
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(
        tempDir.path,
        'ocr_prep_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final preprocessedFile = File(tempPath);
      await preprocessedFile.writeAsBytes(img.encodeJpg(decoded, quality: 95));
      return preprocessedFile;
    } catch (e) {
      print('Pre-processing failed, will use original: $e');
      return null;
    }
  }

  /// Format blocks and lines into natural paragraphs
  String _formatRecognizedText(RecognizedText recognizedText) {
    final StringBuffer buffer = StringBuffer();
    for (final TextBlock block in recognizedText.blocks) {
      for (final TextLine line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // Blank line between blocks
    }
    return buffer.toString().trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
