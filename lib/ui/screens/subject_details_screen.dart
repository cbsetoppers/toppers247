import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/supabase_provider.dart';
import '../../../models/subject_model.dart';
import '../../../models/folder_model.dart';
import '../../../models/material_model.dart';
import '../../../core/utils/pdf_utils.dart';
import '../../features/video/video_player_screen.dart';
import '../../models/pdf_file_model.dart';
import '../../widgets/pdf_download_dialog.dart';

class SubjectDetailsScreen extends ConsumerStatefulWidget {
  final SubjectModel subject;
  const SubjectDetailsScreen({super.key, required this.subject});

  @override
  ConsumerState<SubjectDetailsScreen> createState() =>
      _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends ConsumerState<SubjectDetailsScreen> {
  FolderModel? _currentFolder;
  final List<FolderModel> _history = [];
  bool _isLoading = true;
  List<FolderModel> _folders = [];
  List<MaterialModel> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref
            .read(supabaseServiceProvider)
            .fetchFolders(widget.subject.id, parentId: _currentFolder?.id),
        ref
            .read(supabaseServiceProvider)
            .fetchMaterials(widget.subject.id, folderId: _currentFolder?.id),
      ]);
      setState(() {
        _folders = results[0] as List<FolderModel>;
        _materials = results[1] as List<MaterialModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _enterFolder(FolderModel folder) {
    setState(() {
      if (_currentFolder != null) _history.add(_currentFolder!);
      _currentFolder = folder;
    });
    _loadData();
  }

  void _navigateBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentFolder = _history.removeLast();
        if (_currentFolder?.id == '') _currentFolder = null;
      });
      _loadData();
    } else {
      Navigator.pop(context);
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
          _buildAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 800
                    ? 48.0
                    : 24.0,
                vertical: 24,
              ),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildContentList(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : AppTheme.textHeadingColor,
        ),
        onPressed: _navigateBack,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (_currentFolder?.name ?? widget.subject.name).toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textHeadingColor,
              letterSpacing: 2,
            ),
          ),
          Text(
            _currentFolder != null
                ? widget.subject.name.toUpperCase()
                : 'SUBJECT MATERIALS',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentFolder != null)
          IconButton(
            icon: Icon(
              Icons.home_outlined,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _currentFolder = null;
                _history.clear();
              });
              _loadData();
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildContentList(bool isDark) {
    if (_folders.isEmpty && _materials.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'NO CONTENT YET',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_folders.isNotEmpty) ...[
          _buildSectionHeader('FOLDERS', isDark),
          const SizedBox(height: 16),
          ..._folders.map((f) => _buildFolderTile(f, isDark)),
          const SizedBox(height: 24),
        ],
        if (_materials.isNotEmpty) ...[
          _buildSectionHeader('MATERIALS', isDark),
          const SizedBox(height: 16),
          ..._materials.map((m) => _buildMaterialTile(m, isDark)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white24 : Colors.grey.shade400,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildFolderTile(FolderModel folder, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: isDark ? [] : AppTheme.premiumShadow,
      ),
      child: ListTile(
        onTap: () => _enterFolder(folder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text('📂', style: TextStyle(fontSize: 18))),
        ),
        title: Text(
          folder.name.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
          ),
        ),
        subtitle: Text(
          'Browse nested items',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildMaterialTile(MaterialModel material, bool isDark) {
    final bool isVideo = material.type == 'video';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: isDark ? [] : AppTheme.premiumShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleMaterialClick(material),
        child: Column(
          children: [
            if (isVideo) _buildVideoThumbnail(material),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (!isVideo)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            (material.type == 'pdf' ? Colors.blue : Colors.teal)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          material.type == 'pdf' ? '📄' : '🖼️',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  if (!isVideo) SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : AppTheme.textHeadingColor,
                          ),
                        ),
                        Text(
                          isVideo
                              ? '▶ WATCH VIDEO LECTURE'
                              : (material.type == 'pdf'
                                    ? 'DOCUMENT (PDF)'
                                    : 'IMAGE CONTENT'),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isVideo
                                ? Colors.redAccent
                                : (material.type == 'pdf'
                                      ? Colors.blue
                                      : Colors.teal),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildVideoThumbnail(MaterialModel material) {
    final videoId = _getYoutubeId(material.url);
    final thumb = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg'
        : null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumb != null)
            Image.network(
              thumb,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => Container(color: Colors.black),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          if (material.duration != null)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: Colors.white70,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      material.duration!,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // NEW: Ad free tag
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.orange.shade800],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AD FREE EXPERIENCE',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMaterialClick(MaterialModel material) {
    if (material.type == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VideoPlayerScreen(videoUrl: material.url, title: material.title),
        ),
      );
    } else if (material.type == 'pdf') {
      final driveId = PdfUtils.extractDriveId(material.url);

      PdfDownloadDialog.show(
        context,
        PdfFileModel(
          id: material.id,
          name: material.title,
          driveFileId: driveId,
          url: driveId == null ? material.url : null,
          subject: widget.subject.name,
        ),
      );
    }
  }

  String? _getYoutubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }
}
