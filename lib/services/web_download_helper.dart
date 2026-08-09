// Web-only helper: triggers a browser download of image bytes.
// Only imported when kIsWeb is true.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytesAsFile(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
