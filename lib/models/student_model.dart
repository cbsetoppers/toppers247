import '../services/crypto_service.dart';

class StudentModel {
  final String id;
  final String name;
  final String studentId;
  final String email;
  final String dob;
  final String studentClass;
  final String? classId;
  final String? stream;
  final String? streamId;
  final String? phone;
  final String gender;
  final List<String> competitiveExams;
  final List<String> competitiveExamIds;
  final String board;
  final bool isVerified;
  final bool isOperator;
  final String? role;
  final String? avatarUrl;
  final String subscriptionPlan;

  StudentModel({
    required this.id,
    required this.name,
    required this.studentId,
    required this.email,
    required this.dob,
    required this.studentClass,
    this.classId,
    this.stream,
    this.streamId,
    this.phone,
    required this.gender,
    required this.competitiveExams,
    required this.competitiveExamIds,
    required this.board,
    required this.isVerified,
    this.isOperator = false,
    this.role,
    this.avatarUrl,
    this.subscriptionPlan = 'elite', // All users get full access - subscription model removed
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    try {
      final s = json['stream']?.toString();
      final normalizedStream = s?.toUpperCase() == 'PCBM' ? 'PCMB' : s;
      
      // Handle both 'class' and 'student_class' column names
      final studentClass = json['student_class'] ?? json['class'] ?? '';
      
      return StudentModel(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        studentId: json['student_id'] ?? '',
        email: json['email'] ?? '',
        dob: json['dob'] ?? '',
        studentClass: studentClass,
        classId: json['class_id']?.toString(),
        stream: normalizedStream,
        streamId: json['stream_id']?.toString(),
        phone: json['phone']?.toString(),
        gender: json['gender'] ?? '',
        competitiveExams: (List<String>.from(json['competitive_exams'] ?? []))
            .map((e) => e.toUpperCase())
            .toList(),
        competitiveExamIds: List<String>.from(
          (json['competitive_exam_ids'] as List?)?.map((e) => e.toString()) ??
              [],
        ),
        board: json['board'] ?? 'CBSE',
        isVerified: json['is_verified'] ?? false,
        isOperator: json['is_operator'] ?? false,
        role: json['role'],
        avatarUrl: json['avatar_url'],
        // Subscription model removed — all users get elite (full) access
        subscriptionPlan: 'elite',
      );
    } catch (e) {
      print('ERROR: StudentModel.fromJson failed: $e');
      print('JSON was: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': CryptoService.encryptSymmetric(name),
      'student_id': studentId,
      'email': email,
      'dob': dob,
      'class': studentClass,
      'class_id': classId,
      'stream': stream,
      'stream_id': streamId,
      'phone': phone != null ? CryptoService.encryptSymmetric(phone!) : null,
      'gender': gender,
      'competitive_exams': competitiveExams,
      'competitive_exam_ids': competitiveExamIds,
      'board': board,
      'is_verified': isVerified,
      'is_operator': isOperator,
      'role': role,
      'avatar_url': avatarUrl,
      'subscription_plan': subscriptionPlan,
    };
  }
}
