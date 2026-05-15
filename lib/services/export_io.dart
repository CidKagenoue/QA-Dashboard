import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> savePdfToDownloads(String fileName, Uint8List bytes) async {
  try {
    Directory? downloadsDir;
    try {
      downloadsDir = await getDownloadsDirectory();
    } catch (_) {
      downloadsDir = null;
    }

    if (downloadsDir == null) {
      try {
        downloadsDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        downloadsDir = null;
      }
    }

    if (downloadsDir == null) return null;

    final file = File('${downloadsDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
