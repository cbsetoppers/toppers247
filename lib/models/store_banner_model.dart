class StoreBannerModel {
  final String id;
  final String imageUrl;
  final int orderIndex;
  final DateTime createdAt;

  StoreBannerModel({
    required this.id,
    required this.imageUrl,
    required this.orderIndex,
    required this.createdAt,
  });

  factory StoreBannerModel.fromJson(Map<String, dynamic> json) {
    return StoreBannerModel(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      orderIndex: json['order_index'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
