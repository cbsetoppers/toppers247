class SyllabusChapter {
  final int number;
  final String name;
  final List<String> topics;

  SyllabusChapter({
    required this.number,
    required this.name,
    required this.topics,
  });

  factory SyllabusChapter.fromJson(Map<String, dynamic> json) {
    return SyllabusChapter(
      number: json['number'] ?? 0,
      name: json['name'] ?? '',
      topics: List<String>.from(json['topics'] ?? []),
    );
  }
}

class SyllabusSubject {
  final String name;
  final List<SyllabusChapter> chapters;

  SyllabusSubject({
    required this.name,
    required this.chapters,
  });
}
