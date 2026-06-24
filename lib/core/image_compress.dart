import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Injectable so tests can override without hitting the platform channel.
typedef CompressFn = Future<File?> Function(File source);

Future<File?> _defaultCompress(File source) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    source.absolute.path,
    '${source.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
    minWidth: 1200,
    minHeight: 1200,
    quality: 82,
    format: CompressFormat.jpeg,
  );
  if (result == null) return null;
  return File(result.path);
}

final imageCompressFnProvider = Provider<CompressFn>((_) => _defaultCompress);

class ImageCompressor {
  const ImageCompressor(this._fn);
  final CompressFn _fn;

  /// Compresses [source] and returns the compressed file.
  /// Returns [source] unchanged if compression fails (best-effort).
  Future<File> compress(File source) async {
    final compressed = await _fn(source);
    return compressed ?? source;
  }
}

final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => ImageCompressor(ref.read(imageCompressFnProvider)),
);
