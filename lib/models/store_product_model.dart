class StoreProductModel {
  final String id;
  final String name;
  final String? category;
  final String? description;
  final double sellingPrice;
  final double originalPrice;
  final double discountPercentage;
  final String? imageUrl;
  final List<String>? imageUrls;
  final String? previewUrl;
  final String? fileUrl;
  final int orderIndex;
  final String? exam;
  final String? subject;
  final String? edition; // Added edition field

  StoreProductModel({
    required this.id,
    required this.name,
    this.category,
    this.description,
    required this.sellingPrice,
    required this.originalPrice,
    required this.discountPercentage,
    this.imageUrl,
    this.imageUrls,
    this.previewUrl,
    this.fileUrl,
    required this.orderIndex,
    this.exam,
    this.subject,
    this.edition,
  });

  factory StoreProductModel.fromJson(Map<String, dynamic> json) {
    final double sp = (json['selling_price'] ?? 0).toDouble();
    final double op = (json['original_price'] ?? json['mrp'] ?? sp).toDouble();
    double off = 0;
    if (op > 0) {
      off = ((op - sp) / op * 100).roundToDouble();
    }

    return StoreProductModel(
      id: json['id'].toString(),
      name: json['product_name'] ?? json['name'] ?? 'Untitled Product',
      category: json['category'] ?? json['exam'],
      description: json['description'] ?? json['desc'],
      sellingPrice: sp,
      originalPrice: op,
      discountPercentage: off,
      imageUrl: json['image_url'] ?? json['img'],
      imageUrls: json['image_urls'] is List
          ? List<String>.from(json['image_urls'])
          : null,
      previewUrl: json['preview_url'] ?? json['pdf'],
      fileUrl: json['file_url'],
      orderIndex: json['order_index'] ?? 0,
      exam: json['exam'],
      subject: json['subj'] ?? json['subject'],
      edition: json['edition'],
    );
  }

  double getPlanPrice(String plan) {
    double discount = 0;
    if (plan == 'starter') {
      discount = 0.05;
    } else if (plan == 'pro')
      discount = 0.15;
    else if (plan == 'elite')
      discount = 0.30;

    return (sellingPrice * (1 - discount)).roundToDouble();
  }
}
