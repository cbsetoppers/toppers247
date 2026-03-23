import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/syllabus_model.dart';
import '../../providers/syllabus_provider.dart';
import '../../providers/auth_provider.dart';

class SyllabusTrackerScreen extends ConsumerStatefulWidget {
  const SyllabusTrackerScreen({super.key});

  @override
  ConsumerState<SyllabusTrackerScreen> createState() => _SyllabusTrackerScreenState();
}

class _SyllabusTrackerScreenState extends ConsumerState<SyllabusTrackerScreen> {
  String? _selectedSubject;

  /// Normalize whatever is stored in the student profile to
  /// one of the four keys used in syllabus.json:
  /// 'IXth', 'Xth', 'XIth', 'XIIth'
  String _normalizeClass(String raw) {
    final s = raw.toUpperCase().trim().replaceAll('TH', '').replaceAll(' ', '');
    if (s == '9' || s == 'IX')  return 'IXth';
    if (s == '10' || s == 'X')  return 'Xth';
    if (s == '11' || s == 'XI') return 'XIth';
    if (s == '12' || s == 'XII') return 'XIIth';
    // Fallback – try to return what we got with 'th' appended if it already
    // looks like a roman numeral key (shouldn't happen in practice).
    return raw;
  }

  List<String> _filterSubjects(
    Map<String, List<SyllabusChapter>> subjectsMap,
    String cls,
    String stream,
  ) {
    if (subjectsMap.isEmpty) return [];

    final allSubjects = subjectsMap.keys.toList();
    final su = stream.toUpperCase();

    // IX and X: show everything
    if (cls == 'IXth' || cls == 'Xth') return allSubjects;

    // XI and XII: filter by stream presence
    if (cls == 'XIth' || cls == 'XIIth') {
      final List<String> filtered = [];
      for (final subj in allSubjects) {
        final sobjUpper = subj.toUpperCase();

        // Always show English, Physics, Chemistry
        if (sobjUpper.contains('ENGLISH') || 
            sobjUpper.contains('PHYSICS') || 
            sobjUpper.contains('CHEMISTRY')) {
          filtered.add(subj);
          continue;
        }

        // Logic for Math/Biology/Accountancy etc.
        // If the subject name (partially) appears in the stream or vice versa
        // OR if the stream contains 'ALL' or is empty (meaning all)
        if (su.isEmpty || su.contains('ALL') || 
            su.contains(sobjUpper) || 
            sobjUpper.contains(su)) {
          filtered.add(subj);
        }
      }
      return filtered;
    }

    return allSubjects;
  }

  @override
  Widget build(BuildContext context) {
    final auth       = ref.watch(authProvider).value;
    final studentId  = auth?.id ?? '';
    final rawClass   = auth?.studentClass ?? 'Xth';
    final stream     = auth?.stream ?? '';

    final selectedClass = _normalizeClass(rawClass);

    final syllabusAsync = ref.watch(syllabusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SYLLABUS TRACKER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              'Your Personal Syllabus Tracker',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.black54,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: syllabusAsync.when(
        data: (data) {
          final subjectsMap = data[selectedClass] ?? {};

          if (subjectsMap.isEmpty) {
            return _buildEmptyState(
              'No syllabus found for Class $rawClass.\n'
              'Please check your profile settings.',
            );
          }

          final filteredSubjects = _filterSubjects(subjectsMap, selectedClass, stream);

          // Sort in a standard order
          filteredSubjects.sort((a, b) {
            const order = ['ENGLISH', 'PHYSICS', 'CHEMISTRY', 'BIOLOGY', 'MATHEMATICS', 'MATHS'];
            int idx(String s) {
              final u = s.toUpperCase();
              for (int i = 0; i < order.length; i++) {
                if (u.contains(order[i])) return i;
              }
              return 99;
            }
            return idx(a).compareTo(idx(b));
          });

          if (filteredSubjects.isEmpty) {
            return _buildEmptyState('No subjects matched your stream. Check your profile.');
          }

          // Auto-select the first subject if nothing is selected yet
          // or the previously selected one is no longer valid.
          final effectiveSubject = (_selectedSubject != null && filteredSubjects.contains(_selectedSubject))
              ? _selectedSubject!
              : filteredSubjects.first;

          // Sync state without triggering an extra build loop
          if (_selectedSubject != effectiveSubject) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedSubject = effectiveSubject);
            });
          }

          return Column(
            children: [
              _buildSubjectSelector(filteredSubjects, effectiveSubject),
              Expanded(
                child: _buildChapterList(
                  selectedClass,
                  effectiveSubject,
                  subjectsMap[effectiveSubject] ?? [],
                  studentId,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to load syllabus', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$err', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSubjectSelector(List<String> subjects, String activeSubject) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subj = subjects[index];
          final isSelected = activeSubject == subj;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSubject = subj),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  subj,
                  style: GoogleFonts.outfit(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChapterList(
    String cls,
    String subj,
    List<SyllabusChapter> chapters,
    String studentId,
  ) {
    if (chapters.isEmpty) {
      return _buildEmptyState('No chapters found for $subj.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) => _buildChapterCard(cls, subj, chapters[index], studentId),
    );
  }

  Widget _buildChapterCard(String cls, String subj, SyllabusChapter chapter, String studentId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressState = ref.watch(syllabusProgressProvider(studentId));

    int completed = 0;
    for (final topic in chapter.topics) {
      if (progressState['$cls|$subj|${chapter.number}|$topic'] ?? false) {
        completed++;
      }
    }
    final double percent = chapter.topics.isEmpty ? 0 : completed / chapter.topics.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? Colors.grey[900]?.withOpacity(0.8) : Colors.white,
      elevation: 4,
      shadowColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ExpansionTile(
        title: Text(
          subj.toUpperCase().contains('ENGLISH') 
            ? chapter.name 
            : 'Chapter ${chapter.number}: ${chapter.name}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: percent,
                backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 4),
              Text(
                '$completed/${chapter.topics.length} Topics Completed',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: chapter.topics.map((topic) {
          final isCompleted = progressState['$cls|$subj|${chapter.number}|$topic'] ?? false;
          return _buildTopicTile(cls, subj, chapter.number, topic, isCompleted, studentId);
        }).toList(),
      ),
    ).animate().fadeIn(delay: 50.ms * chapter.number).slideY(begin: 0.1);
  }

  Widget _buildTopicTile(
    String cls,
    String subj,
    int chNum,
    String topic,
    bool isCompleted,
    String studentId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          ref
              .read(syllabusProgressProvider(studentId).notifier)
              .toggleTopic(cls, subj, chNum, topic);
        },
        leading: Icon(
          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isCompleted ? Theme.of(context).primaryColor : Colors.grey,
        ),
        title: Text(
          topic,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted
                ? (isDark ? Colors.white70 : Colors.black54)
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        dense: true,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
