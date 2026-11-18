import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum DocumentFilterType {
  original,
  magicColor,
  blackAndWhite,
  grayscale,
}

class FilterService {
  /// Friendly display name for filter types
  static String getFilterName(DocumentFilterType type) {
    switch (type) {
      case DocumentFilterType.magicColor:
        return 'Magic Color';
      case DocumentFilterType.blackAndWhite:
        return 'B&W';
      case DocumentFilterType.grayscale:
        return 'Grayscale';
      case DocumentFilterType.original:
        return 'Original';
    }
  }

  /// Process an image file and apply the desired document filter
  /// Returns the path to the newly saved filtered image.
  static Future<String> applyFilter({
    required String imagePath,
    required DocumentFilterType filterType,
  }) async {
    if (filterType == DocumentFilterType.original) {
      return imagePath;
    }

    final inputFile = File(imagePath);
    if (!await inputFile.exists()) return imagePath;

    try {
      // Run heavy image manipulation in compute isolate to keep UI 100% fluid
      final bytes = await inputFile.readAsBytes();
      final filteredBytes = await compute(_processImageBytes, {
        'bytes': bytes,
        'filterType': filterType.index,
      });

      if (filteredBytes == null) return imagePath;

      final appDir = await getApplicationDocumentsDirectory();
      final enhancedDir = Directory(p.join(appDir.path, 'scancraft_images'));
      if (!await enhancedDir.exists()) {
        await enhancedDir.create(recursive: true);
      }

      final fileName = 'enhanced_${DateTime.now().millisecondsSinceEpoch}_${p.basename(imagePath)}';
      final outputFile = File(p.join(enhancedDir.path, fileName));
      await outputFile.writeAsBytes(filteredBytes);
      return outputFile.path;
    } catch (e) {
      print('FilterService error applying filter: $e');
      return imagePath;
    }
  }

  /// Apply filter to a list of page paths (e.g. for batch scan)
  static Future<List<String>> applyFilterToBatch({
    required List<String> imagePaths,
    required DocumentFilterType filterType,
    void Function(int current, int total)? onProgress,
  }) async {
    if (filterType == DocumentFilterType.original) {
      return List.from(imagePaths);
    }

    List<String> processedPaths = [];
    for (int i = 0; i < imagePaths.length; i++) {
      final enhanced = await applyFilter(
        imagePath: imagePaths[i],
        filterType: filterType,
      );
      processedPaths.add(enhanced);
      if (onProgress != null) {
        onProgress(i + 1, imagePaths.length);
      }
    }
    return processedPaths;
  }

  /// Isolate top-level / static function for image processing
  static Uint8List? _processImageBytes(Map<String, dynamic> params) {
    try {
      final Uint8List bytes = params['bytes'];
      final int filterIndex = params['filterType'];
      final filterType = DocumentFilterType.values[filterIndex];

      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Downscale if ridiculously large to prevent memory spike
      if (image.width > 2600 || image.height > 2600) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 2600 : null,
          height: image.height >= image.width ? 2600 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      switch (filterType) {
        case DocumentFilterType.magicColor:
          // Magic Color: Cleans background shadows (brightens) + Boosts contrast and color saturation
          // Makes text pop out sharp while whitening paper background
          image = img.adjustColor(
            image,
            contrast: 1.45,
            brightness: 1.15,
            saturation: 1.10,
          );
          break;

        case DocumentFilterType.blackAndWhite:
          // B&W Photocopy: Convert to grayscale, then high contrast boost
          image = img.grayscale(image);
          image = img.adjustColor(
            image,
            contrast: 2.1,
            brightness: 1.18,
          );
          break;

        case DocumentFilterType.grayscale:
          // Clean Grayscale document
          image = img.grayscale(image);
          image = img.adjustColor(
            image,
            contrast: 1.25,
            brightness: 1.05,
          );
          break;

        case DocumentFilterType.original:
          break;
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 92));
    } catch (e) {
      print('Isolate processing error: $e');
      return null;
    }
  }
}
