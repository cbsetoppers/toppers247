import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_model.dart';
import 'pdf_storage_service.dart';

class DownloadManager with ChangeNotifier {
  final List<PdfFileModel> _pdfs = [];
  List<PdfFileModel> get pdfs => _pdfs;

  bool _isInitDone = false;
  bool get isInitDone => _isInitDone;

  DownloadManager() {
    // Optionally init on constructor if needed, but the user spec suggests manual init()
  }

  Future<void> init(List<PdfFileModel> incomingPdfs) async {
    final prefs = await SharedPreferences.getInstance();
    _pdfs.clear();
    _pdfs.addAll(incomingPdfs);

    for (var pdf in _pdfs) {
      final isCached = prefs.getBool('pdf_cached_${pdf.id}') ?? false;
      final fileExists = await PdfStorageService.isFileDownloaded(pdf.id);
      
      if (isCached && fileExists) {
        pdf.status = DownloadStatus.downloaded;
        pdf.progress = 1.0;
      } else {
        pdf.status = DownloadStatus.notDownloaded;
        pdf.progress = 0.0;
        // Clean up prefs if file is gone
        if (isCached && !fileExists) {
          prefs.remove('pdf_cached_${pdf.id}');
        }
      }
    }
    _isInitDone = true;
    notifyListeners();
  }

  Future<void> downloadPdf(PdfFileModel pdf) async {
    if (pdf.status == DownloadStatus.downloading) return;

    pdf.status = DownloadStatus.downloading;
    pdf.progress = 0.0;
    notifyListeners();

    try {
      final localPath = await PdfStorageService.getLocalPath(pdf.id, pdf.name);
      final downloadUrl = pdf.downloadUrl;
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final file = File(localPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        pdf.progress = total > 0 ? (received / total) : 0.5;
        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      client.close();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pdf_cached_${pdf.id}', true);
      await PdfStorageService.savePdfName(pdf.id, pdf.name);

      pdf.status = DownloadStatus.downloaded;
      pdf.progress = 1.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Download failed for ${pdf.id}: $e');
      pdf.status = DownloadStatus.failed;
      pdf.progress = 0.0;
      notifyListeners();
    }
  }

  Future<void> deletePdf(PdfFileModel pdf) async {
    await PdfStorageService.deletePdf(pdf.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pdf_cached_${pdf.id}');
    
    pdf.status = DownloadStatus.notDownloaded;
    pdf.progress = 0.0;
    notifyListeners();
  }

  // Find a PDF by ID if you need to update it separately
  PdfFileModel? findById(String id) {
    try {
      return _pdfs.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
