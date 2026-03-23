import '../services/crypto_service.dart';

class MaterialModel {
  final String id;
  final String? folderId;
  final String subjectId;
  final String title;
  final String type; // pdf, image, video
  final String url;
  final int orderIndex;
  final String? duration;
  final DateTime createdAt;

  MaterialModel({
    required this.id,
    this.folderId,
    required this.subjectId,
    required this.title,
    required this.type,
    required this.url,
    this.duration,
    required this.orderIndex,
    required this.createdAt,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: json['id'].toString(),
      folderId: json['folder_id']?.toString(),
      subjectId: json['subject_id'].toString(),
      title: CryptoService.decryptSymmetric(json['title'] ?? json['name'] ?? json['label'] ?? 'Untitled Material'),
      type: (json['type'] ?? 'pdf').toString().toLowerCase(),
      url: CryptoService.decryptSymmetric(json['url'] ?? json['file_url'] ?? json['pdf_url'] ?? json['link'] ?? json['preview_url'] ?? ''),
      duration: json['duration']?.toString(),
      orderIndex: json['order_index'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
