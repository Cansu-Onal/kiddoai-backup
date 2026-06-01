import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadPaintingBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob([bytes], "image/png");
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..click();

  html.Url.revokeObjectUrl(url);
}