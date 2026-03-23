import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/folder_model.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/crypto_service.dart';
import '../core/constants/app_constants.dart';

import '../models/subject_model.dart';
import '../models/material_model.dart';
import '../models/store_product_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final Dio _dio = Dio();

  // Admin service role client removed for security. Use the normal client with
  // proper RLS policies from the client or server-side functions.

  // PicoApps AI Details
  static const String _aiPk =
      'v1-Z0FBQUFBQnBwUzNHaVFaVWtuNTIwdHNsTUpMUGJDa0dOZVg1RHp0YXAyTG4tRkpNSERoNkNYWW9fc0RCbVJJaEE3UnlUZ0tMUEQ5bGJrejZZTUFpWk8yVWQ5T2tJRXZhbXc9PQ==';
  static const String _llmUrl =
      'https://backend.buildpicoapps.com/aero/run/llm-api?pk=$_aiPk';
  static const String _imageUrl =
      'https://backend.buildpicoapps.com/aero/run/image-generation-api?pk=$_aiPk';

  String _processUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.startsWith('/assets/')) {
      return 'https://toppers247.onrender.com$url';
    }
    if (_isDriveUrl(url)) {
      return _getDirectUrl(url);
    }

    return url;
  }

  /// Checks if a URL is a Google Drive URL.
  bool _isDriveUrl(String url) {
    return url.contains('drive.google.com') ||
        url.contains('drive.usercontent.google.com');
  }

  /// Get a direct-download URL for Google Drive links
  String _getDirectUrl(String url) {
    if (!_isDriveUrl(url)) return url;

    // Patterns: /d/ID/view, /file/d/ID, id=ID, open?id=ID
    final reg1 = RegExp(r'\/d\/([a-zA-Z0-9_-]{20,})');
    final reg2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})');

    final id = reg1.firstMatch(url)?.group(1) ?? reg2.firstMatch(url)?.group(1);

    if (id != null) {
      // docs.google.com is usually more reliable for bytes access
      return 'https://docs.google.com/uc?export=download&id=$id';
    }

    // Fallback for usercontent URLs
    if (url.contains('drive.usercontent.google.com')) {
      if (!url.contains('export=download')) {
        final sep = url.contains('?') ? '&' : '?';
        return '$url${sep}export=download';
      }
    }
    return url;
  }

  // AUTH
  Future<StudentModel?> login(String identifier, String password) async {
    String email = identifier.trim();

    // 1. ID Lookup if identifier is not an email
    if (!email.contains('@')) {
      final response = await _client
          .from('students')
          .select('email')
          .eq('student_id', email.toUpperCase())
          .maybeSingle();

      if (response == null) {
        throw Exception('Student ID not found');
      }
      email = response['email'];
    }

    // 2. Sign In
    final AuthResponse res = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    if (res.user != null) {
      final authUid = res.user!.id; // ← canonical UUID from auth.users
      // ALWAYS look up by UUID — this is the only correct join between auth ↔ students
      final profile = await fetchProfileById(authUid);
      if (profile == null) {
        throw Exception(
          'Profile not found. Account exists but has no student record. '
          'Please contact support or try re-registering.',
        );
      }
      return profile;
    }
    return null;
  }

  Future<int> fetchUserCount() async {
    try {
      final res = await _client.from('students').select('id');
      return res.length;
    } catch (e) {
      return 0;
    }
  }

  /// Fetches the single app-wide settings row from the `settings` table.
  /// Returns [AppSettings.defaults] (maintenance=false) on any error so the
  /// app NEVER gets stuck due to a Supabase connectivity issue.
  Future<AppSettings> fetchAppSettings() async {
    try {
      final res = await _client
          .from('settings')
          .select()
          .limit(1)
          .maybeSingle();
      if (res != null) {
        debugPrint('⚙️ App settings loaded: maintenance=${res['maintenance']}');
        return AppSettings.fromJson(res);
      }
    } catch (e) {
      debugPrint('⚠️ fetchAppSettings error: $e — using defaults (app open)');
    }
    return AppSettings.defaults;
  }

  Future<StudentModel?> register({
    required String name,
    required String dob,
    required String studentClass,
    String? stream,
    required String email,
    String? phone,
    required String password,
    List<String>? competitiveExams,
    String gender = 'OTHER',
  }) async {
    debugPrint('🔄 Starting registration for: $email');

    String? userId;

    // 1. Create Auth User
    try {
      debugPrint('🔄 Step 1: Creating auth user...');
      final AuthResponse authRes = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': name.trim()},
      );
      if (authRes.user != null) {
        userId = authRes.user!.id;
        debugPrint('✅ Auth user created: $userId');
      }
    } catch (e) {
      debugPrint('⚠️ Auth signup failed: $e');
      if (e.toString().contains('User already registered')) {
        // User exists - try to get their ID
        try {
          final existing = await _client
              .from('students')
              .select('id')
              .eq('email', email.trim().toLowerCase())
              .maybeSingle();
          if (existing != null) {
            userId = existing['id'].toString();
            debugPrint('✅ Found existing student: $userId');
          } else {
            throw Exception(
              'User exists in auth but not in students table. Please contact support.',
            );
          }
        } catch (inner) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    if (userId == null)
      throw Exception('Failed to create or identify user account.');
    // Promote to non-nullable — below this line userId is guaranteed non-null
    final String uid = userId;

    // 2. CRITICAL: Ensure active session before DB insert so RLS is satisfied.
    // auth.signUp may return user without an active session (e.g., email confirmation mode).
    // We explicitly sign in so auth.uid() == uid when inserting to students table.
    // Use a mutable variable so we can correct it if the session gives a different UUID.
    String resolvedUid = uid;
    try {
      debugPrint('🔄 Step 2: Establishing session for DB insert...');
      final session = _client.auth.currentSession;
      if (session == null || session.user.id != uid) {
        await _client.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        debugPrint('✅ Session established');
      } else {
        debugPrint('✅ Session already active');
      }
      // ALWAYS re-read the UUID from the active session after signIn.
      // Guarantees this resolvedUid == auth.uid() == students.id — no mismatch possible.
      final activeSession = _client.auth.currentSession;
      if (activeSession != null && activeSession.user.id != uid) {
        debugPrint(
          '⚠️ UUID mismatch! Correcting: ${activeSession.user.id} (was $uid)',
        );
        resolvedUid = activeSession.user.id;
      }
    } catch (e) {
      debugPrint('⚠️ Session establishment warning: $e — continuing...');
    }

    // 3. Check if student profile already exists (avoid duplicate insert)
    try {
      final existing = await _client
          .from('students')
          .select('id')
          .eq('id', resolvedUid)
          .maybeSingle();
      if (existing != null) {
        debugPrint('✅ Profile already exists, fetching...');
        final profile = await _client
            .from('students')
            .select()
            .eq('id', resolvedUid)
            .single();
        return StudentModel.fromJson(profile);
      }
    } catch (e) {
      debugPrint('⚠️ Profile check: $e');
    }

    // 4. Generate student ID
    final autoId =
        'CT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    debugPrint('🔄 Student ID: $autoId');

    // 5. Insert to students table
    // Use resolvedUid — this is the UUID that matches auth.uid() in the current session
    final studentData = {
      'id': resolvedUid,
      'name': name.trim(),
      'dob': dob,
      'student_class': studentClass,
      'stream': stream ?? '',
      'email': email.trim().toLowerCase(),
      'phone': phone?.trim(),
      'student_id': autoId,
      'gender': gender,
      'competitive_exams': competitiveExams ?? [],
      'board': 'CBSE',
      'is_verified': false, // Only operators get verified status
      'subscription_plan': 'elite', // All features unlocked
    };

    debugPrint('🔄 Step 6: Inserting student data with UUID: $resolvedUid');
    debugPrint('🔄 Data: $studentData');

    try {
      final result = await _client
          .from('students')
          .insert(studentData)
          .select();
      debugPrint('✅ DB insert success: $result');
    } catch (e) {
      debugPrint('❌ DB insert FAILED: $e — trying upsert fallback...');
      try {
        final result = await _client
            .from('students')
            .upsert(studentData, onConflict: 'id')
            .select();
        debugPrint('✅ DB upsert success: $result');
      } catch (upsertError) {
        debugPrint('❌ DB upsert also FAILED: $upsertError');
        throw Exception('Failed to save student profile: $upsertError');
      }
    }

    // 7. Fetch and return profile
    debugPrint('🔄 Step 7: Fetching profile...');
    try {
      final profile = await _client
          .from('students')
          .select()
          .eq('id', resolvedUid)
          .single();
      debugPrint('✅ Profile fetched: $profile');
      return StudentModel.fromJson(profile);
    } catch (e) {
      debugPrint('❌ Profile fetch failed: $e');
      // Return stub model
      return StudentModel(
        id: resolvedUid,
        name: name.trim(),
        studentId: autoId,
        email: email.trim().toLowerCase(),
        dob: dob,
        studentClass: studentClass,
        stream: stream,
        phone: phone,
        gender: gender,
        competitiveExams: competitiveExams ?? [],
        competitiveExamIds: [],
        board: 'CBSE',
        isVerified: false, // Only operators get verified status
        subscriptionPlan: 'elite',
      );
    }
  }

  Future<void> updateProfile({
    required String id,
    required String name,
    required String dob,
    required String studentClass,
    String? stream,
    String? phone,
    required String gender,
    required List<String> competitiveExams,
    String? board,
  }) async {
    try {
      final updates = {
        'name': CryptoService.encryptSymmetric(name),
        'dob': dob,
        'class': studentClass,
        'stream': stream,
        'phone': phone != null ? CryptoService.encryptSymmetric(phone) : null,
        'gender': gender,
        'competitive_exams': competitiveExams,
      };

      if (board != null) updates['board'] = board;

      // Try students table first
      try {
        final res = await _client
            .from('students')
            .update(updates)
            .eq('id', id)
            .select()
            .maybeSingle();
        if (res != null) return;
      } catch (e) {
        debugPrint('Not a student or student update failed: $e');
      }

      // If not a student, try operators (only name is editable for now)
      await _client.from('operators').update({'name': name}).eq('id', id);
    } catch (e) {
      debugPrint('Update Profile Error: $e');
      rethrow;
    }
  }

  Future<void> updateAvatarUrl(String id, String avatarUrl) async {
    try {
      await _client
          .from('students')
          .update({'avatar_url': avatarUrl})
          .eq('id', id);
    } catch (e) {
      debugPrint('Update Avatar Error: $e');
      rethrow;
    }
  }

  Future<void> updateSubscriptionPlan(String userId, String plan) async {
    try {
      await _client
          .from('students')
          .update({
            'subscription_plan': plan.toLowerCase(),
            'subscription_start_date': DateTime.now().toIso8601String(),
            'subscription_end_date': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      debugPrint('Update Subscription Plan Error: $e');
      rethrow;
    }
  }

  Future<List<String>> fetchStreams({String? classId}) async {
    if (classId != null) {
      final List<dynamic> response = await _client
          .from('class_streams')
          .select('streams(name)')
          .eq('class_id', classId);
      
      return response.map((e) {
        final name = (e['streams'] as Map<String, dynamic>)['name'].toString();
        return name.toUpperCase() == 'PCBM' ? 'PCMB' : name.toUpperCase();
      }).toList();
    }

    final List<dynamic> response = await _client
        .from('streams')
        .select('name')
        .order('name');
    final fetched = response
        .map((e) => e['name'].toString().toUpperCase())
        .toList();
    return fetched.map((s) => s == 'PCBM' ? 'PCMB' : s).toList();
  }

  // Fetch dynamic competitive exams from Supabase
  Future<List<String>> fetchCompetitiveExams() async {
    final List<dynamic> response = await _client
        .from('competitive_exams')
        .select('name')
        .order('name');
    return response.map((e) => e['name'].toString().toUpperCase()).toList();
  }

  // Fetch dynamic classes from Supabase
  Future<List<Map<String, dynamic>>> fetchClasses() async {
    final List<dynamic> response = await _client
        .from('classes')
        .select('id, name, class_type')
        .order('name');
    return response.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> sendPasswordReset(String identifier) async {
    String email = identifier.trim().toLowerCase();

    // 1. If it's a Student ID, find the email first
    if (!email.contains('@')) {
      final response = await _client
          .from('students')
          .select('email')
          .eq('student_id', email.toUpperCase())
          .maybeSingle();

      if (response != null) {
        email = response['email'];
      } else {
        throw Exception('Student ID not found');
      }
    }

    // 2. Send the reset email
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'cbsetoppers://reset-password',
    );
  }

  Future<StudentModel?> fetchProfile(String email) async {
    final profile = await _client
        .from('students')
        .select()
        .ilike('email', email)
        .maybeSingle();

    if (profile != null) {
      return StudentModel.fromJson(profile);
    }

    final operator = await _client
        .from('operators')
        .select()
        .ilike('email', email)
        .maybeSingle();

    if (operator != null) {
      return StudentModel(
        id: operator['id'].toString(),
        name: operator['name'] ?? 'Operator',
        studentId:
            'OP_${operator['id'].toString().substring(0, 5).toUpperCase()}',
        email: email,
        dob: '',
        studentClass: 'Admin',
        gender: 'MALE',
        competitiveExams: [],
        competitiveExamIds: [],
        board: 'CBSE',
        isVerified: true,
        isOperator: true,
        role: operator['role'],
      );
    }
    return null;
  }

  /// Fetch student profile by Supabase auth UUID (students.id = auth.users.id).
  /// This is the CORRECT join — UUID is the foreign key, not email.
  /// Email can change; UUID never changes.
  Future<StudentModel?> fetchProfileById(String uuid) async {
    debugPrint('🔍 fetchProfileById: $uuid');

    // 1. students table
    try {
      final profile = await _client
          .from('students')
          .select()
          .eq('id', uuid)
          .maybeSingle();
      if (profile != null) {
        debugPrint('✅ Student profile found for UUID: $uuid');
        return StudentModel.fromJson(profile);
      }
    } catch (e) {
      debugPrint('⚠️ students lookup by UUID error: $e');
    }

    // 2. operators table (admin accounts)
    try {
      final operator = await _client
          .from('operators')
          .select()
          .eq('id', uuid)
          .maybeSingle();
      if (operator != null) {
        debugPrint('✅ Operator profile found for UUID: $uuid');
        final opEmail = operator['email']?.toString() ?? '';
        return StudentModel(
          id: uuid,
          name: operator['name'] ?? 'Operator',
          studentId: 'OP_${uuid.substring(0, 5).toUpperCase()}',
          email: opEmail,
          dob: '',
          studentClass: 'Admin',
          gender: 'MALE',
          competitiveExams: [],
          competitiveExamIds: [],
          board: 'CBSE',
          isVerified: true,
          isOperator: true,
          role: operator['role'],
        );
      }
    } catch (e) {
      debugPrint('⚠️ operators lookup by UUID error: $e');
    }

    debugPrint('❌ No profile found for UUID: $uuid');
    return null;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // CONTENT
  Future<List<SubjectModel>> fetchSubjects(
    String targetClass, {
    String? targetStream,
    List<String>? exams,
  }) async {
    PostgrestFilterBuilder query = _client.from('subjects').select();

    // For Admin, fetch all subjects without filtering
    // For regular users, fetch subjects that include their class
    if (targetClass != 'Admin') {
      // Normalize class name for matching
      final normalizedClass = _normalizeClassForDb(targetClass);
      query = query.contains('target_classes', [normalizedClass]);
    }

    final List<dynamic> response = await query.order('order_index');

    List<SubjectModel> subjects = response.map((s) {
      final processed = Map<String, dynamic>.from(s);
      if (processed['icon_url'] != null) {
        processed['icon_url'] = _processUrl(processed['icon_url']);
      }
      return SubjectModel.fromJson(processed);
    }).toList();

    // Client-side filtering for streams and exams
    if (targetClass != 'Admin') {
      final normalizedStream = _normalizeStream(targetStream);
      final normalizedClass = _normalizeClassForDb(targetClass);

      return subjects.where((s) {
        final stStreams = s.targetStreams ?? [];
        final stExams = s.targetExams ?? [];

        // Stream Check: empty list means all streams, otherwise must match
        bool matchesStream = _matchesStream(stStreams, normalizedStream);

        // Competitive Exam Check
        bool matchesExam = _matchesExams(stExams, exams, normalizedClass);

        return matchesStream && matchesExam;
      }).toList();
    }

    return subjects;
  }

  String _normalizeClassForDb(String cls) {
    // Normalize class names to match database format
    final s = cls.toUpperCase().trim();
    if (s == 'IX' || s == '9' || s == 'IXTH') return 'IX';
    if (s == 'X' || s == '10' || s == 'XTH') return 'X';
    if (s == 'XI' || s == '11' || s == 'XITH') return 'XI';
    if (s == 'XII' || s == '12' || s == 'XIITH') return 'XII';
    if (s == 'XII+' || s == 'DROPPER' || s == 'DROP' || s == '13') {
      return 'XII+';
    }
    return cls;
  }

  String? _normalizeStream(String? stream) {
    if (stream == null || stream.isEmpty) return null;
    return stream.trim();
  }

  bool _matchesStream(List<String> subjectStreams, String? userStream) {
    // Empty subject streams means available to all streams
    if (subjectStreams.isEmpty) return true;

    // If user has no stream, show subjects with no stream restriction
    if (userStream == null) return false;

    // Exact match is required now to support dynamic streams
    return subjectStreams.any((ss) => 
      ss.toUpperCase().trim() == userStream.toUpperCase().trim()
    );
  }

  bool _matchesExams(
    List<String> subjectExams,
    List<String>? userExams,
    String targetClass,
  ) {
    // Empty subject exams means general subject (available to all/no exam required)
    if (subjectExams.isEmpty) return true;

    // No user exams means show general subjects
    if (userExams == null || userExams.isEmpty) return false;

    // For XII+ (dropper), they MUST have matching exams - no general subjects
    if (targetClass == 'XII+' || targetClass == 'XII+') {
      return userExams.any(
        (ue) => subjectExams.any(
          (se) =>
              se.toUpperCase().contains(ue.toUpperCase()) ||
              ue.toUpperCase().contains(se.toUpperCase()),
        ),
      );
    }

    // For others, show if any exam matches
    return userExams.any(
      (ue) => subjectExams.any(
        (se) =>
            se.toUpperCase().contains(ue.toUpperCase()) ||
            ue.toUpperCase().contains(se.toUpperCase()),
      ),
    );
  }

  Future<List<FolderModel>> fetchFolders(
    String subjectId, {
    String? parentId,
  }) async {
    var query = _client.from('folders').select().eq('subject_id', subjectId);
    if (parentId != null) {
      query = query.eq('parent_id', parentId);
    } else {
      query = query.filter('parent_id', 'is', null);
    }
    final List<dynamic> response = await query.order('order_index');
    return response.map((f) => FolderModel.fromJson(f)).toList();
  }

  Future<List<MaterialModel>> fetchMaterials(
    String subjectId, {
    String? folderId,
  }) async {
    var query = _client.from('materials').select().eq('subject_id', subjectId);
    if (folderId != null) {
      query = query.eq('folder_id', folderId);
    } else {
      query = query.filter('folder_id', 'is', null);
    }
    final List<dynamic> response = await query.order('order_index');
    return response.map((m) {
      final processed = Map<String, dynamic>.from(m);
      // Process all possible URL fields
      for (final key in ['url', 'file_url', 'pdf_url', 'link', 'preview_url']) {
        if (processed[key] != null) {
          processed[key] = _processUrl(processed[key].toString());
        }
      }
      return MaterialModel.fromJson(processed);
    }).toList();
  }

  Future<List<MaterialModel>> fetchLatestMaterials({
    String? targetClass,
    int limit = 10,
  }) async {
    final List<dynamic> response = await _client
        .from('materials')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return response.map((m) {
      final processed = Map<String, dynamic>.from(m);
      for (final key in ['url', 'file_url', 'pdf_url', 'link', 'preview_url']) {
        if (processed[key] != null) {
          processed[key] = _processUrl(processed[key].toString());
        }
      }
      return MaterialModel.fromJson(processed);
    }).toList();
  }

  // STORE
  Future<List<StoreProductModel>> fetchStoreProducts() async {
    try {
      final List<dynamic> response = await _client
          .from('store_products')
          .select()
          .order('order_index');
      return response.map((p) => StoreProductModel.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Fetch Store Products Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchStoreBanners() async {
    try {
      final List<dynamic> response = await _client
          .from('store_banners')
          .select()
          .order('order_index');
      return response.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Fetch Banners Error: $e');
      return [];
    }
  }

  Future<String> fetchDailyQuote(StudentModel? student) async {
    try {
      final name = student?.name.split(' ')[0] ?? 'Student';
      final prompt =
          "Generate a short, powerful, and inspiring motivational quote (max 15 words) "
          "for a student named $name who is in class ${student?.studentClass ?? 'X'}. "
          "Make it unique and academic-focused. Return ONLY the quote text.";

      final response = await _dio.post(
        'https://cbsetopper.tarun-pncml123.workers.dev',
        data: {'question': prompt},
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode == 200) {
        return response.data?.toString() ?? "Your only limit is your mind.";
      }
      return "Believe in yourself and all that you are.";
    } catch (e) {
      return "Education is the most powerful weapon.";
    }
  }

  // AI CHAT (BuildPicoapps PicoApps API)
  Future<String> chatWithAI(
    String userMessage, {
    StudentModel? student,
    bool isQuizMode = false,
  }) async {
    try {
      String studentContext = "";
      if (student != null) {
        studentContext =
            "User Profile: Name: ${student.name}, Class: ${student.studentClass}, Stream: ${student.stream ?? 'N/A'}, Board: ${student.board}, Exams: ${student.competitiveExams.join(', ')}. ";
      }

      final systemPersona =
          "You are TopperAI, a friendly, professional career guide and academic specialist. "
          "You specialize in CBSE, Board Exams, and competitive exams specifically: JEE, NEET, and CUET. "
          "$studentContext"
          "ADVANCED CAPABILITIES: You are an elite AI with scientific reasoning and visualization capabilities. "
          "1. MATHEMATICS: Use LaTeX syntax for all equations (inline: \$E=mc^2\$, block: \$\$ ... \$\$). "
          "2. VISUALS: If asked for a graph or chart, provide a Markdown Table or Mermaid diagram. "
          "3. QUIZ GENERATION: If asked for a quiz (not in quiz mode), respond in JSON format only. "
          'JSON Structure: {"type": "quiz", "topic": "TOPIC", "questions": [{"question": "...", "options": ["A","B","C","D"], "correctIndex": 0, "explanation": "..."}]} '
          "CRITICAL: correctIndex must be 0-3 matching the correct option. "
          "MATH FORMATTING: ALWAYS use \$...\$ for inline math and \$\$...\$\$ for block math. "
          "Follow instructions precisely! If the user asks to generate, create or make an image, photo, or picture by describing it, "
          "You will reply with /image + description. Otherwise, You will respond normally. Avoid additional explanations.";

      String prompt;
      if (isQuizMode) {
        // In quiz mode, ONLY output the raw JSON - no system persona fluff
        final quizInstruction =
            "You are a highly accurate quiz generator for academic subjects. "
            "$studentContext"
            "TASK: Generate a multiple-choice quiz based on the user's request.\n"
            "CRITICAL RULES — follow EVERY rule with no exceptions:\n"
            "1. Output ONLY the raw JSON object. No markdown, no code fences (no ```), no explanation text before or after.\n"
            "2. The response must begin with '{' and end with '}'. Nothing else.\n"
            "3. JSON structure MUST be exactly: {\"type\": \"quiz\", \"topic\": \"TOPIC_NAME\", \"questions\": [...]}\n"
            "4. Each question MUST have: {\"question\": \"...\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"correctIndex\": N, \"explanation\": \"...\"}\n"
            "5. 'options' MUST contain exactly 4 strings.\n"
            "6. 'correctIndex' is a zero-based integer (0=A, 1=B, 2=C, 3=D).\n"
            "7. Generate EXACTLY the number of questions requested by the user. Do NOT stop early.\n"
            "8. If 15 questions are requested, the 'questions' array MUST have exactly 15 items.\n"
            "9. All 4 options must be distinct, plausible, and academically accurate.\n"
            "10. Explanations must clearly state WHY the correct answer is right.\n"
            "11. For math/science questions, write equations in plain text (e.g., E=mc^2, F=ma).\n"
            "12. Do NOT include any LaTeX or markdown inside the JSON strings.\n\n"
            "User request: $userMessage";
        prompt = quizInstruction;
      } else {
        prompt = '$systemPersona\n\nUser: $userMessage';
      }

      // Use PicoApps LLM API
      final response = await _dio.post(
        _llmUrl,
        data: {'prompt': prompt},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        String aiText = '';
        final responseData = response.data;
        if (responseData is Map && responseData['status'] == 'success') {
          aiText = responseData['text']?.toString() ?? '';
        } else if (responseData is String) {
          aiText = responseData;
        }

        if (aiText.isEmpty) {
          return 'TopperAI is thinking... Please try again!';
        }

        // Handle image generation trigger
        if (aiText.trimLeft().startsWith('/image')) {
          final description = aiText.replaceFirst('/image', '').trim();
          return await generateImage(description);
        }
        return aiText;
      }
      return 'TopperAI is currently processing another query. Please try again in a moment!';
    } catch (e) {
      return 'Connection Error: $e';
    }
  }

  Future<String> generateImage(String description) async {
    try {
      final response = await _dio.post(
        _imageUrl,
        data: {'prompt': description},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map &&
            data['status'] == 'success' &&
            data['imageUrl'] != null) {
          return 'IMAGE_URL:${data['imageUrl']}';
        }
      }
      return 'Image Generation Error';
    } catch (e) {
      return 'Image Error: $e';
    }
  }

  // PURCHASE HISTORY
  Future<void> savePurchase({
    required String id,
    required String studentId,
    required String productName,
    required String productCode,
    required String amount,
    String? fileUrl,
  }) async {
    try {
      await _client.from('purchase_history').insert({
        'id': id,
        'student_id': studentId,
        'product_name': CryptoService.encryptSymmetric(productName),
        'product_code': productCode,
        'amount': amount,
        'purchase_date': DateTime.now().toIso8601String(),
        'file_url': fileUrl != null
            ? CryptoService.encryptSymmetric(fileUrl)
            : null,
      });
    } catch (e) {
      debugPrint('Save Purchase Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPurchaseHistory(
    String studentId,
  ) async {
    try {
      final response = await _client
          .from('purchase_history')
          .select()
          .eq('student_id', studentId)
          .order('purchase_date', ascending: false);
      final list = List<Map<String, dynamic>>.from(response);
      return list.map((item) {
        final e = Map<String, dynamic>.from(item);
        if (e['product_name'] != null) {
          e['product_name'] = CryptoService.decryptSymmetric(e['product_name']);
        }
        if (e['file_url'] != null) {
          e['file_url'] = CryptoService.decryptSymmetric(e['file_url']);
        }
        return e;
      }).toList();
    } catch (e) {
      debugPrint('Fetch Purchase History Error: $e');
      return [];
    }
  }
}
