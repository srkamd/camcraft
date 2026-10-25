import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from a scanned image path
  Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.trim().isEmpty) {
        return 'No readable text was detected in this document.';
      }
      return recognizedText.text;
    } catch (e) {
      print('OCR extraction error: $e');
      return 'Failed to extract text: $e';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
