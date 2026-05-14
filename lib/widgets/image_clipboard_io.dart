import 'dart:typed_data';

/// Stub — only called on web. Native drop handler uses the
/// `XFile.readAsBytes()` path directly.
Future<Uint8List> readBlobUrlBytes(String url) =>
    throw UnsupportedError('readBlobUrlBytes is web-only');

/// Native platforms can't read raw image bytes from the system
/// clipboard without per-OS plugins, so the paste flow there falls
/// back to text-only paste handled by the caller.
Future<Uint8List?> readImageFromClipboard() async => null;
