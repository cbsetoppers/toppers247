import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../services/download_manager.dart';
import '../services/pdf_storage_service.dart';
import '../screens/pdf_viewer_screen.dart';

class PdfDownloadDialog extends StatefulWidget {
  final PdfFileModel pdf;

  const PdfDownloadDialog({super.key, required this.pdf});

  static Future<void> show(BuildContext context, PdfFileModel pdf) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PdfDownloadDialog(pdf: pdf),
    );
  }

  @override
  State<PdfDownloadDialog> createState() => _PdfDownloadDialogState();
}

class _PdfDownloadDialogState extends State<PdfDownloadDialog> {
  final DownloadManager _manager = DownloadManager();
  bool _isAutoOpening = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    await _manager.init([widget.pdf]);
    if (widget.pdf.status == DownloadStatus.downloaded) {
      _openPdf();
    } else {
      _manager.downloadPdf(widget.pdf);
    }
    
    _manager.addListener(_onManagerUpdate);
  }

  void _onManagerUpdate() {
    if (widget.pdf.status == DownloadStatus.downloaded && !_isAutoOpening) {
      _isAutoOpening = true;
      _openPdf();
    }
  }

  Future<void> _openPdf() async {
    final path = await PdfStorageService.getLocalPath(widget.pdf.id, widget.pdf.name);
    if (!mounted) return;
    
    // Close dialog
    Navigator.pop(context);
    
    // Navigate to viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          localPath: path,
          title: widget.pdf.name,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final progress = widget.pdf.progress;
        final status = widget.pdf.status;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (status == DownloadStatus.failed ? Colors.red : Colors.blue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == DownloadStatus.failed ? Icons.error_outline : Icons.file_download_rounded,
                  color: status == DownloadStatus.failed ? Colors.red : Colors.blue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                status == DownloadStatus.failed ? 'DOWNLOAD FAILED' : 'PREPARING DOCUMENT',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: status == DownloadStatus.failed ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.pdf.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),
              if (status != DownloadStatus.failed) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(progress * 100).toInt()}% READY',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue,
                  ),
                ),
              ] else ...[
                 Text(
                  'Oops! Something went wrong while fetching the file. Please check your connection.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                status == DownloadStatus.failed ? 'CLOSE' : 'CANCEL',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey),
              ),
            ),
            if (status == DownloadStatus.failed)
              ElevatedButton(
                onPressed: () {
                  _manager.downloadPdf(widget.pdf);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('RETRY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }
}
