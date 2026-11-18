import 'package:flutter_test/flutter_test.dart';
import 'package:camcraft/services/filter_service.dart';

void main() {
  group('FilterService Unit Tests', () {
    test('getFilterName returns correct user-facing labels', () {
      expect(FilterService.getFilterName(DocumentFilterType.magicColor), equals('Magic Color'));
      expect(FilterService.getFilterName(DocumentFilterType.blackAndWhite), equals('B&W'));
      expect(FilterService.getFilterName(DocumentFilterType.grayscale), equals('Grayscale'));
      expect(FilterService.getFilterName(DocumentFilterType.original), equals('Original'));
    });

    test('All DocumentFilterType enum values are accounted for', () {
      for (final type in DocumentFilterType.values) {
        final name = FilterService.getFilterName(type);
        expect(name.isNotEmpty, isTrue);
      }
    });
  });
}
