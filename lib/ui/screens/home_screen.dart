import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter/foundation.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/aesthetic_click_effect.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/subject_model.dart';
import '../../models/student_model.dart';
import 'profile_screen.dart';
import 'subject_details_screen.dart';

import 'package:flutter/services.dart';
import 'dart:io';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, userAsync.value, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 800
                    ? 48.0
                    : 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildAiQuote(userAsync.value, isDark),
                  const SizedBox(height: 24),
                  _buildSubjectsList(userAsync.value, isDark),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context, isDark);
        if (shouldExit == true) {
          exit(0);
        }
      },
      child: Scaffold(body: body),
    );
  }

  Future<bool?> _showExitDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBlack : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.2)),
        ),
        title: Text(
          'EXIT APPLICATION?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'ARE YOU SURE YOU WANT TO QUIT T0PPERS 24/7?',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'KEEP STUDYING',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent, width: 1),
              ),
            ),
            child: Text(
              'EXIT NOW',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    StudentModel? student,
    bool isDark,
  ) {
    return SliverAppBar(
      pinned: false,
      expandedHeight: 120,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getGreeting().toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white38 : Colors.grey,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    student?.name.split(' ')[0].toUpperCase() ?? 'STUDENT',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child:
                              student != null &&
                                  student.avatarUrl != null &&
                                  student.avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: student.avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      _buildDefaultAvatar(student),
                                  errorWidget: (_, _, _) =>
                                      _buildDefaultAvatar(student),
                                  width: 40,
                                  height: 40,
                                )
                              : _buildDefaultAvatar(student),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: const [SizedBox(width: 8)],
    );
  }

  Widget _buildAiQuote(StudentModel? student, bool isDark) {
    final quoteAsync = ref.watch(dailyQuoteProvider);

    return quoteAsync
        .when(
          data: (quote) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.secondaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    quote,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        )
        .animate()
        .fadeIn()
        .slideY(begin: 0.2);
  }

  Widget _buildSubjectsList(StudentModel? student, bool isDark) {
    if (student == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      data: (subjects) {
        // Subjects WITHOUT target_exams are grouped dynamically by their 'tag'
        final nonExamSubs = subjects.where((s) {
          final hasExams = s.targetExams != null && s.targetExams!.isNotEmpty;
          return !hasExams;
        }).toList();

        // Group by tag string
        final Map<String, List<SubjectModel>> tagGroups = {};
        for (final sub in nonExamSubs) {
          // Fallback to 'GENERAL' if tag is missing or empty
          final tag = sub.tag.trim().isEmpty ? 'GENERAL' : sub.tag.trim().toUpperCase();
          tagGroups.putIfAbsent(tag, () => []).add(sub);
        }

        // Sort tags by their name
        final sortedTags = tagGroups.keys.toList()
          ..sort((a, b) => a.compareTo(b));

        final examSections = _buildExamSections(student, subjects, isDark);

        final dynamicSections = sortedTags.map((tagString) {
          final tagSubjects = tagGroups[tagString]!;
          final displayTitle = tagString;
          final secColor = AppTheme.getSectionColor(displayTitle);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(displayTitle, isDark, secColor),
              const SizedBox(height: 12),
              _buildSubjectGrid(tagSubjects, isDark, secColor),
              const SizedBox(height: 24),
            ],
          );
        }).toList();

        return Column(
          children: [
            ...dynamicSections,
            ...examSections,
            if (subjects.isEmpty) _buildEmptyState(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  List<Widget> _buildExamSections(
    StudentModel student,
    List<SubjectModel> allSubjects,
    bool isDark,
  ) {
    final widgets = <Widget>[];
    final userExams = student.competitiveExams;

    if (userExams.isEmpty) return widgets;

    for (final exam in userExams) {
      final examSubjects = allSubjects.where((s) {
        if (s.targetExams == null || s.targetExams!.isEmpty) return false;
        return s.targetExams!.contains(exam.toUpperCase()) ||
            s.targetExams!.contains(exam.toLowerCase()) ||
            s.targetExams!.any((e) => e.toLowerCase() == exam.toLowerCase());
      }).toList();

      if (examSubjects.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          _buildExamSection(exam.toUpperCase(), examSubjects, isDark),
        );
      }
    }

    return widgets;
  }

  Widget _buildExamSection(
    String examName,
    List<SubjectModel> subjects,
    bool isDark,
  ) {
    final examColor = AppTheme.getSectionColor(examName);
    final examIcons = {
      'JEE': Icons.science_rounded,
      'NEET': Icons.medical_services_rounded,
      'CUET': Icons.school_rounded,
    };
    final examIcon = examIcons[examName] ?? Icons.assignment_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: examColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: examColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(examIcon, size: 14, color: examColor),
                  const SizedBox(width: 6),
                  Text(
                    'FOR $examName',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: examColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildExamSubjectGrid(subjects, isDark, examColor),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildExamSubjectGrid(
    List<SubjectModel> subjects,
    bool isDark,
    Color examColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1100 ? 4 : (screenWidth > 800 ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final sub = subjects[index];
        return _buildExamSubjectCard(sub, isDark, examColor);
      },
    );
  }

  Widget _buildExamSubjectCard(
    SubjectModel subject,
    bool isDark,
    Color examColor,
  ) {
    return AestheticClickEffect(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectDetailsScreen(subject: subject),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBlack : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: examColor.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: examColor.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: examColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: examColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: _buildSubjectIcon(subject, examColor),
              ),
              SizedBox(height: 16),
              Text(
                subject.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: examColor.withOpacity(0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: examColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subject.code.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: examColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (subject.tag.isNotEmpty) Text(
                    subject.tag.toLowerCase().toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildSectionTitle(String title, bool isDark, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectGrid(
    List<SubjectModel> subjects,
    bool isDark,
    Color accentColor,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1100 ? 4 : (screenWidth > 800 ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final sub = subjects[index];
        return _buildSubjectCard(sub, isDark, accentColor);
      },
    );
  }

  Widget _buildSubjectCard(
    SubjectModel subject,
    bool isDark,
    Color accentColor,
  ) {
    return AestheticClickEffect(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectDetailsScreen(subject: subject),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBlack : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: accentColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: _buildSubjectIcon(subject, accentColor),
              ),
              SizedBox(height: 16),
              Text(
                subject.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: accentColor.withOpacity(0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subject.code.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (subject.tag.isNotEmpty) Text(
                    subject.tag.toLowerCase().toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildSubjectIcon(SubjectModel subject, Color color) {
    final iconUrl = subject.iconUrl;
    if (iconUrl == null || iconUrl.isEmpty) {
      return Icon(Icons.menu_book, color: color, size: 28);
    }

    return Image.network(
      iconUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.menu_book, color: color, size: 28),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: color,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'NO CLASSES FOUND',
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) {
      return 'Good morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon,';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening,';
    } else {
      return 'Good night,';
    }
  }

  Widget _buildDefaultAvatar(StudentModel? student) {
    return Image.asset(
      student?.gender == 'FEMALE'
          ? 'assets/female_avtar.png'
          : 'assets/male_avtar.png',
      fit: BoxFit.cover,
      width: 40,
      height: 40,
    );
  }
}
