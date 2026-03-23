class FolderModel {
  final String id;
  final String subjectId;
  final String? parentId;
  final String name;
  final int orderIndex;
  final String createdAt;

  FolderModel({
    required this.id,
    required this.subjectId,
    this.parentId,
    required this.name,
    required this.orderIndex,
    required this.createdAt,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'].toString(),
      subjectId: json['subject_id'].toString(),
      parentId: json['parent_id']?.toString(),
      name: json['name'] ?? '',
      orderIndex: json['order_index'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
