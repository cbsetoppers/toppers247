import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/auth_provider.dart';
import '../../../models/student_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/image_upload_service.dart';
import 'login_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import 'purchase_history_screen.dart';
import '../../../providers/theme_provider.dart';
import 'my_downloads_screen.dart';
import 'edit_profile_screen.dart';
import '../../../providers/settings_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int? _expandedIndex;
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploadService = ImageUploadService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final user = userAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHero(user, isDark),
                const SizedBox(height: 32),
                _buildGroupedSettings(user, context, isDark),
                const SizedBox(height: 48),
                _buildFooter(isDark),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : AppTheme.textHeadingColor,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'PROFILE',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : AppTheme.textHeadingColor,
          letterSpacing: 3,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _handleLogout(context),
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHero(StudentModel user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickAvatar(user),
            onDoubleTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            ),
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => _buildDefaultAvatar(user),
                              errorWidget: (_, _, _) =>
                                  _buildDefaultAvatar(user),
                            )
                          : _buildDefaultAvatar(user),
                    ),
                  ),
                ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textHeadingColor,
                  letterSpacing: 1,
                ),
              ),
              if (user.isOperator) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.verified_rounded,
                    color: _getRoleColor(user.role ?? ''),
                    size: 18,
                  ),
                ),
              ],
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'STUDENT ID: ${user.studentId}',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
                letterSpacing: 2,
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Tap to choose photo • Double Tap to edit profile',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(StudentModel user) {
    return Image.asset(
      user.gender == 'FEMALE'
          ? 'assets/female_avtar.png'
          : 'assets/male_avtar.png',
      fit: BoxFit.cover,
    );
  }

  Future<void> _pickAvatar(StudentModel user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? AppTheme.cardBlack : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CHANGE PROFILE PHOTO',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              title: Text(
                'Take a Photo',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: Text(
                  'Remove Photo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == 'remove') {
      await _updateAvatar(null);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source == 'gallery' ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final uploadedUrl = await _uploadService.uploadImage(File(image.path));

      await _updateAvatar(uploadedUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _updateAvatar(String? avatarUrl) async {
    try {
      if (avatarUrl == null) {
        await ref.read(authProvider.notifier).removeAvatar();
      } else {
        await ref.read(authProvider.notifier).updateAvatarUrl(avatarUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGroupedSettings(
    StudentModel user,
    BuildContext context,
    bool isDark,
  ) {
    final themeState = ref.watch(themeProvider);
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('ACCOUNT SETTINGS', isDark),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: border),
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
              children: [
                ExpansionTile(
                  key: ValueKey('academic_${_expandedIndex == 0}'),
                  initiallyExpanded: _expandedIndex == 0,
                  onExpansionChanged: (expanded) =>
                      setState(() => _expandedIndex = expanded ? 0 : null),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    'ACADEMIC & PERSONAL',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textHeadingColor,
                    ),
                  ),
                  children:
                      [
                            _buildInfoRow(
                              Icons.class_outlined,
                              'CLASS / BOARD',
                              '${user.studentClass} | ${user.board}',
                            ),
                            if (user.stream != null)
                              _buildInfoRow(
                                Icons.science_outlined,
                                'STREAM',
                                user.stream!,
                              ),
                            if (user.competitiveExams.isNotEmpty)
                              _buildInfoRow(
                                Icons.assignment_outlined,
                                'COMPETITIVE EXAM',
                                user.competitiveExams.join(', '),
                              ),
                            _buildInfoRow(
                              Icons.email_outlined,
                              'EMAIL ADDRESS',
                              user.email,
                            ),
                            if (user.phone != null)
                              _buildInfoRow(
                                Icons.phone_outlined,
                                'MOBILE NUMBER',
                                user.phone!,
                              ),
                            _buildInfoRow(
                              Icons.cake_outlined,
                              'DATE OF BIRTH',
                              user.dob,
                            ),
                            const SizedBox(height: 12),
                          ]
                          .animate(interval: 50.ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: -0.05, curve: Curves.easeOut),
                ),
                Divider(color: border, height: 1),
                ExpansionTile(
                  key: ValueKey('personalization_${_expandedIndex == 1}'),
                  initiallyExpanded: _expandedIndex == 1,
                  onExpansionChanged: (expanded) =>
                      setState(() => _expandedIndex = expanded ? 1 : null),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(
                    'THEMES & APPEARANCE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textHeadingColor,
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) =>
                        ref.read(themeProvider.notifier).toggleBrightness(),
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: border, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'CHOOSE APP COLOR',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade500,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildColorSelector(
                              const Color(0xFFFFD700),
                              themeState.primaryColor,
                              false,
                            ),
                            _buildColorSelector(
                              const Color(0xFFA020F0),
                              themeState.primaryColor,
                              false,
                            ),
                            _buildColorSelector(
                              const Color(0xFF0096FF),
                              themeState.primaryColor,
                              false,
                            ),
                            _buildColorSelector(
                              const Color(0xFFFFA500),
                              themeState.primaryColor,
                              false,
                            ),
                            _buildColorSelector(
                              const Color(0xFF00C853),
                              themeState.primaryColor,
                              false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(color: border, height: 1),
                        const SizedBox(height: 16),
                        _buildQuickToolsToggle(isDark),
                        const SizedBox(height: 16),
                        _buildAiBotSelector(isDark),
                        const SizedBox(height: 4),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                  ],
                ),
                Divider(color: border, height: 1),
                _buildActionRow(
                  Icons.download_done_rounded,
                  'MY DOWNLOADS',
                  'Offline PDFs saved on device',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyDownloadsScreen(),
                    ),
                  ),
                ),
                Divider(color: border, height: 1),
                _buildActionRow(
                  Icons.shopping_bag_outlined,
                  'PURCHASE HISTORY',
                  'View Orders & Receipts',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseHistoryScreen(),
                    ),
                  ),
                ),
                Divider(color: border, height: 1),
                _buildActionRow(
                  Icons.help_center_outlined,
                  'CUSTOMER SUPPORT',
                  '24/7 Priority Assistance',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen(),
                    ),
                  ),
                ),
                Divider(color: border, height: 1),
                _buildActionRow(
                  Icons.info_outline_rounded,
                  'ABOUT T0PPERS 24/7',
                  'v2.0.0 (2026 Edition)',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(Color color, Color selectedColor, bool isLocked) {
    final isSelected = color.value == selectedColor.value;
    return GestureDetector(
      onTap: () {
        ref.read(themeProvider.notifier).setColor(color);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }

  Widget _buildQuickToolsToggle(bool isDark) {
    final settings = ref.watch(studySettingsProvider);
    final notifier = ref.read(studySettingsProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.handyman_outlined,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHOW QUICK TOOLS',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textHeadingColor,
                  ),
                ),
                Text(
                  'Floating tools on study page',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        Switch(
          value: settings.showQuickTools,
          onChanged: (val) => notifier.toggleQuickTools(val),
          activeThumbColor: AppTheme.primaryColor,
        ),
      ],
    );
  }
  Widget _buildAiBotSelector(bool isDark) {
    final settings = ref.watch(studySettingsProvider);
    final notifier = ref.read(studySettingsProvider.notifier);
    final primary = AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.psychology_outlined, size: 18, color: primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEFAULT AI ASSISTANT',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textHeadingColor,
                  ),
                ),
                Text(
                  'Choose your preferred chat companion',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildAiPill('deepseek', 'DeepSeek', settings.defaultAiBot == 'deepseek', notifier, primary, isDark),
            const SizedBox(width: 8),
            _buildAiPill('chatgpt', 'ChatGPT', settings.defaultAiBot == 'chatgpt', notifier, primary, isDark),
            const SizedBox(width: 8),
            _buildAiPill('gemini', 'Gemini', settings.defaultAiBot == 'gemini', notifier, primary, isDark),
            const SizedBox(width: 8),
            _buildAiPill('google', 'Google', settings.defaultAiBot == 'google', notifier, primary, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildAiPill(String id, String name, bool selected, StudySettingsNotifier notifier, Color primary, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.setDefaultAiBot(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary.withOpacity(0.6) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              (id == 'google')
                  ? Icon(Icons.search_rounded,
                      size: 20, color: selected ? (isDark ? Colors.white : Colors.black87) : Colors.grey)
                  : Image.asset(
                      'assets/$id.png',
                      width: 20,
                      height: 20,
                      color: selected ? null : Colors.grey.withOpacity(0.6),
                      colorBlendMode: selected ? null : BlendMode.srcIn,
                    ),
              const SizedBox(height: 6),
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, bool isDark) {
    return Row(
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
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppTheme.secondaryColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
    );
  }

  Widget _buildFooter(bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            'T0PPERS 24/7',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MADE WITH PRIDE FOR FUTURE TOPPERS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white10 : Colors.grey.shade300,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to sign out from your account?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Me Signed In',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes, Logout',
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
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'co-founder':
        return const Color(0xFF6A0DAD); // Purple
      case 'founder':
      case 'developer':
        return const Color(0xFFFFC107); // Gold
      case 'ceo':
        return const Color(0xFF1E88E5); // Blue
      case 'mentor':
        return const Color(0xFF2ECC71); // Green
      case 'supervisor':
        return const Color(0xFF424242); // Dark Grey
      default:
        return AppTheme.primaryColor;
    }
  }
}
