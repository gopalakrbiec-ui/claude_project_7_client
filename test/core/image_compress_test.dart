import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_event_editor/core/image_compress.dart';

void main() {
  group('ImageCompressor', () {
    test('returns compressed file when fn succeeds', () async {
      final source = File('/fake/source.jpg');
      final compressed = File('/fake/compressed.jpg');

      final compressor = ImageCompressor((_) async => compressed);
      final result = await compressor.compress(source);

      expect(result.path, compressed.path);
    });

    test('falls back to source when fn returns null', () async {
      final source = File('/fake/source.jpg');

      final compressor = ImageCompressor((_) async => null);
      final result = await compressor.compress(source);

      expect(result.path, source.path);
    });

    test('provider uses injected fn', () async {
      final source = File('/fake/source.jpg');
      final compressed = File('/fake/compressed.jpg');

      final container = ProviderContainer(
        overrides: [
          imageCompressFnProvider.overrideWithValue((_) async => compressed),
        ],
      );
      addTearDown(container.dispose);

      final compressor = container.read(imageCompressorProvider);
      final result = await compressor.compress(source);

      expect(result.path, compressed.path);
    });

    test('compressFnProvider override is respected end-to-end', () async {
      final source = File('/fake/original.jpg');
      int callCount = 0;

      final container = ProviderContainer(
        overrides: [
          imageCompressFnProvider.overrideWithValue((f) async {
            callCount++;
            return File('${f.path}.compressed');
          }),
        ],
      );
      addTearDown(container.dispose);

      final compressor = container.read(imageCompressorProvider);
      await compressor.compress(source);

      expect(callCount, 1);
    });
  });
}
