import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/syllabus_model.dart';

final syllabusProvider = FutureProvider<Map<String, Map<String, List<SyllabusChapter>>>>((ref) async {
  try {
    print('SYLLABUS_LOAD: Starting load from assets/syllabus.json...');
    final content = await rootBundle.loadString('assets/syllabus.json');
    print('SYLLABUS_LOAD: File read successful. Parsing JSON...');
    final Map<String, dynamic> data = json.decode(content);
    
    Map<String, Map<String, List<SyllabusChapter>>> result = {};
    
    data.forEach((cls, subjects) {
      result[cls] = {};
      (subjects as Map<String, dynamic>).forEach((subj, chapters) {
        result[cls]![subj] = (chapters as List).map((c) => SyllabusChapter.fromJson(c)).toList();
      });
    });
    
    print('SYLLABUS_LOAD: Successfully parsed ${result.length} classes.');
    return result;
  } catch (e, stack) {
    print('SYLLABUS_LOAD_ERROR: $e');
    print(stack);
    rethrow;
  }
});

class SyllabusProgressNotifier extends StateNotifier<Map<String, bool>> {
  final String studentId;
  DatabaseReference? _dbRef;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  SyllabusProgressNotifier(this.studentId) : super({}) {
    if (kIsWeb) {
      _dbRef = FirebaseDatabase.instance.ref();
    }
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadProgress();
  }

  String _sanitizeKey(String key) {
    return key.replaceAll('.', '_').replaceAll('#', '_').replaceAll('\$', '_').replaceAll('[', '_').replaceAll(']', '_').replaceAll('/', '_');
  }

  String _getLocalStorageKey() {
    return 'syllabus_progress_${_sanitizeKey(studentId)}';
  }

  Future<void> _loadProgress() async {
    if (studentId.isEmpty) return;
    
    try {
      if (kIsWeb) {
        // Web: Use Firebase
        print('SYLLABUS_PROGRESS: Loading from Firebase for student: $studentId');
        final snapshot = await _dbRef!.child('syllabus_progress').child(_sanitizeKey(studentId)).get();
        print('SYLLABUS_PROGRESS: Firebase snapshot exists: ${snapshot.exists}');
        if (snapshot.exists && snapshot.value is Map) {
          final Map<dynamic, dynamic> data = snapshot.value as Map;
          state = data.map((key, value) => MapEntry(key.toString(), value as bool));
          print('SYLLABUS_PROGRESS: Loaded ${state.length} items from Firebase');
        }
      } else {
        // Non-web: Use local storage
        print('SYLLABUS_PROGRESS: Loading from local storage for student: $studentId');
        final prefs = await SharedPreferences.getInstance();
        final key = _getLocalStorageKey();
        final data = prefs.getString(key);
        if (data != null) {
          final Map<String, dynamic> decoded = json.decode(data);
          state = decoded.map((key, value) => MapEntry(key.toString(), value as bool));
          print('SYLLABUS_PROGRESS: Loaded ${state.length} items from local storage');
        }
      }
    } catch (e) {
      print('SYLLABUS_PROGRESS: Error loading: $e');
    }
  }

  Future<void> _saveProgress() async {
    if (studentId.isEmpty) return;
    
    try {
      if (kIsWeb) {
        // Web: Use Firebase
        for (final entry in state.entries) {
          await _dbRef!.child('syllabus_progress').child(_sanitizeKey(studentId)).child(_sanitizeKey(entry.key)).set(entry.value);
        }
        print('SYLLABUS_PROGRESS: Saved ${state.length} items to Firebase');
      } else {
        // Non-web: Use local storage
        final prefs = await SharedPreferences.getInstance();
        final key = _getLocalStorageKey();
        await prefs.setString(key, json.encode(state));
        print('SYLLABUS_PROGRESS: Saved ${state.length} items to local storage');
      }
    } catch (e) {
      print('SYLLABUS_PROGRESS: Error saving: $e');
    }
  }

  Future<void> toggleTopic(String classId, String subjectId, int chapterNum, String topic) async {
    final key = '$classId|$subjectId|$chapterNum|$topic';
    final newValue = !(state[key] ?? false);
    
    // Optimistic update
    final newState = Map<String, bool>.from(state);
    newState[key] = newValue;
    state = newState;

    await _saveProgress();
  }

  bool isCompleted(String classId, String subjectId, int chapterNum, String topic) {
    final key = '$classId|$subjectId|$chapterNum|$topic';
    return state[key] ?? false;
  }
}

final syllabusProgressProvider = StateNotifierProvider.family<SyllabusProgressNotifier, Map<String, bool>, String>((ref, studentId) {
  return SyllabusProgressNotifier(studentId);
});
