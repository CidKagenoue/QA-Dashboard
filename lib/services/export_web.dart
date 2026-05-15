// Web implementation uses dart:html to trigger a browser download
import 'dart:typed_data';
import 'dart:html' as html;

Future<String?> savePdfToDownloads(String fileName, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  // Return the filename as a success indicator to avoid fallback print dialog.
  return fileName;
}
