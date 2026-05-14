import 'package:flutter/widgets.dart';

/// Native path: just `Image.network`. CORS doesn't apply to the
/// Dart VM HTTP client.
Widget buildWebSafeImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? errorPlaceholder,
}) {
  return Image.network(
    url,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorPlaceholder == null
        ? null
        : (_, _, _) => errorPlaceholder,
  );
}
