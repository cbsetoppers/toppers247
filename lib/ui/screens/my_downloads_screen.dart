import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/pdf_storage_service.dart';

class MyDownloadsScreen extends StatefulWidget {
  const MyDownloadsScreen({super.key});

  @override
  State<MyDownloadsScreen> createState() => _MyDownloadsScreenState();
}

class _MyDownloadsScreenState extends State<MyDownloadsScreen> {
  List<File> _pdfFiles = [];
  List<File> _freeMaterials = [];
  List<File> _paidMaterials = [];
  List<File> _receipts = [];
  Map<String, String> _pdfNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedPdfs();
  }

  Future<void> _loadDownloadedPdfs() async {
    setState(() => _loading = true);
    final files = <File>[];

    try {
      final appSupport = await getApplicationSupportDirectory();
      final pdfCacheDir = Directory('${appSupport.path}/pdf_cache');
      if (await pdfCacheDir.exists()) {
        final entries = pdfCacheDir.listSync(recursive: false);
        for (final entry in entries) {
          if (entry is File && entry.path.endsWith('.pdf')) {
            files.add(entry);
          }
        }
      }
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      final entries = docs.listSync(recursive: true);
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.pdf')) {
          if (!files.any((f) => f.path == entry.path)) {
            files.add(entry);
          }
        }
      }
    } catch (_) {}

    _pdfNames = await PdfStorageService.getAllPdfNames();

    files.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    if (mounted) {
      final free = <File>[];
      final paid = <File>[];
      final receipts = <File>[];

      for (final file in files) {
        final nameStr = _pdfName(file).toLowerCase();
        final baseStr = file.uri.pathSegments.last.toLowerCase();

        if (baseStr.contains('receipt') || nameStr.contains('receipt')) {
          receipts.add(file);
        } else if (nameStr.contains('product file') || baseStr.contains('product file')) {
          paid.add(file);
        } else {
          free.add(file);
        }
      }

      setState(() {
        _pdfFiles = files;
        _freeMaterials = free;
        _paidMaterials = paid;
        _receipts = receipts;
        _loading = false;
      });
    }
  }

  Future<void> _openPdf(File file) async {
    try {
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot open file: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deletePdf(File file) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBlack : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete PDF?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete "${_pdfName(file)}" from storage.',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        
        final pdfId = _extractPdfId(file.uri.pathSegments.last);
        if (pdfId != null) {
          await PdfStorageService.deletePdf(pdfId);
        }
        
        _loadDownloadedPdfs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted successfully', style: GoogleFonts.outfit()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e', style: GoogleFonts.outfit()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  String _pdfName(File file) {
    final base = file.uri.pathSegments.last;
    final pdfId = _extractPdfId(base);
    
    if (pdfId != null && _pdfNames.containsKey(pdfId)) {
      return _pdfNames[pdfId]!;
    }
    
    final nameWithoutExt = base.endsWith('.pdf')
        ? base.substring(0, base.length - 4)
        : base;
    if (nameWithoutExt.contains('_')) {
      final parts = nameWithoutExt.split('_');
      if (parts.length > 1) {
        return parts.sublist(1).join(' ').replaceAll('-', ' ');
      }
    }
    return nameWithoutExt.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  String? _extractPdfId(String filename) {
    final match = RegExp(r'^([^_]+)_(.+)\.pdf$').firstMatch(filename);
    return match?.group(1);
  }

  String _fileSizeStr(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '${bytes}B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } catch (_) {
      return '';
    }
  }

  String _lastModified(File file) {
    try {
      final dt = file.lastModifiedSync().toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppTheme.textHeadingColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'MY DOWNLOADS',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textHeadingColor,
                letterSpacing: 3,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: _loadDownloadedPdfs,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _pdfFiles.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 48,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NO DOWNLOADS YET',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PDFs you download from subjects\nwill appear here for offline access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white24 : Colors.black26,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_pdfFiles.length} PDF${_pdfFiles.length == 1 ? '' : 'S'} SAVED',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (_freeMaterials.isNotEmpty) _buildSection('FREE MATERIALS', _freeMaterials, isDark),
          if (_paidMaterials.isNotEmpty) _buildSection('PAID MATERIALS', _paidMaterials, isDark),
          if (_receipts.isNotEmpty) _buildSection('RECEIPTS', _receipts, isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<File> files, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 16),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(files.length, (i) {
              final file = files[i];
              final isLast = i == files.length - 1;
              return Column(
                children: [
                  _buildPdfTile(file, isDark),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      indent: 76,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfTile(File file, bool isDark) {
    return InkWell(
      onTap: () => _openPdf(file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // PDF icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),

            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pdfName(file),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textHeadingColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fileSizeStr(file),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _lastModified(file),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
              color: isDark ? AppTheme.cardBlack : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              onSelected: (value) {
                if (value == 'open') _openPdf(file);
                if (value == 'delete') _deletePdf(file);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text('Open', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
