class SubjectModel {
  final String id;
  final String name;
  final String code;
  final String tag;
  final String? targetClass;
  final List<String>? targetClasses;
  final String? targetStream;
  final List<String>? targetStreams;
  final List<String>? targetExams;
  final String? iconUrl;
  final int orderIndex;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.tag,
    this.targetClass,
    this.targetClasses,
    this.targetStream,
    this.targetStreams,
    this.targetExams,
    this.iconUrl,
    required this.orderIndex,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      tag: json['tag'] ?? '',
      targetClass: json['target_class'],
      targetClasses: json['target_classes'] != null
          ? List<String>.from(json['target_classes'])
          : null,
      targetStream: json['target_stream'],
      targetStreams: json['target_streams'] != null
          ? List<String>.from(json['target_streams'])
          : null,
      targetExams: json['target_exams'] != null
          ? List<String>.from(json['target_exams'])
          : null,
      iconUrl: json['icon_url'],
      orderIndex: json['order_index'] ?? 0,
    );
  }
}
