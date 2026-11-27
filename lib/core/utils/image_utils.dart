import 'dart:convert';
import 'dart:typed_data';

/// Checks whether the given byte data represents an SVG image.
///
/// This is a lightweight and fast heuristic used to detect SVG files
/// when the MIME type is unknown or unreliable (e.g., when downloading
/// images from Odoo or other backends).
///
/// **How it works:**
/// - Decodes the bytes as UTF-8 (with malformed sequences allowed).
/// - Checks for the presence of the `<svg` substring, which is the standard
///   opening tag for SVG documents.
///
/// **Limitations:**
/// - Not 100% accurate (could have false positives if a text file contains `<svg`).
/// - Does not validate the full SVG structure.
/// - Works well for most real-world cases where binary images (PNG, JPG, WebP)
///   would fail this check.
///
/// Returns `true` if the bytes appear to be an SVG image.
bool isSvgBytes(Uint8List bytes) {
  final str = utf8.decode(bytes, allowMalformed: true);
  return str.contains('<svg');
}
