import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfStorageService {
  static const String _pdfNamesKey = 'pdf_downloaded_names';

  static Future<String> getCacheDirectoryPath() async {
    final base = await getApplicationSupportDirectory();
    final cacheDir = Directory('${base.path}/pdf_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  static Future<String> getLocalPath(String pdfId, String pdfName) async {
    final cacheDirPath = await getCacheDirectoryPath();
    final sanitizedName = _sanitizeFileName(pdfName);
    return '$cacheDirPath/${pdfId}_$sanitizedName.pdf';
  }

  static Future<bool> isFileDownloaded(String pdfId) async {
    final cacheDir = Directory(await getCacheDirectoryPath());
    if (!await cacheDir.exists()) return false;
    
    final files = cacheDir.listSync();
    return files.any((f) => f.path.contains(pdfId) && f.path.endsWith('.pdf'));
  }

  static Future<void> deletePdf(String pdfId) async {
    final cacheDir = Directory(await getCacheDirectoryPath());
    if (!await cacheDir.exists()) return;
    
    final files = cacheDir.listSync();
    for (final file in files) {
      if (file is File && file.path.contains(pdfId) && file.path.endsWith('.pdf')) {
        await file.delete();
        break;
      }
    }
    
    await _removePdfName(pdfId);
  }

  static Future<void> savePdfName(String pdfId, String pdfName) async {
    final prefs = await SharedPreferences.getInstance();
    final allNames = prefs.getStringList(_pdfNamesKey) ?? [];
    final index = allNames.indexWhere((entry) => entry.startsWith('$pdfId:'));
    if (index >= 0) {
      allNames[index] = '$pdfId:$pdfName';
    } else {
      allNames.add('$pdfId:$pdfName');
    }
    await prefs.setStringList(_pdfNamesKey, allNames);
  }

  static Future<String?> getPdfName(String pdfId) async {
    final prefs = await SharedPreferences.getInstance();
    final allNames = prefs.getStringList(_pdfNamesKey) ?? [];
    for (final entry in allNames) {
      final parts = entry.split(':');
      if (parts.length == 2 && parts[0] == pdfId) {
        return parts[1];
      }
    }
    return null;
  }

  static Future<void> _removePdfName(String pdfId) async {
    final prefs = await SharedPreferences.getInstance();
    final allNames = prefs.getStringList(_pdfNamesKey) ?? [];
    allNames.removeWhere((entry) => entry.startsWith('$pdfId:'));
    await prefs.setStringList(_pdfNamesKey, allNames);
  }

  static Future<Map<String, String>> getAllPdfNames() async {
    final prefs = await SharedPreferences.getInstance();
    final allNames = prefs.getStringList(_pdfNamesKey) ?? [];
    final Map<String, String> result = {};
    for (final entry in allNames) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }
}
