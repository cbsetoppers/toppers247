class SubscriptionPlanModel {
  final String id;
  final String name;
  final int priceMonthly;
  final int priceQuarterly;
  final int priceYearly;
  final List<String> features;
  final bool isFeatured;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.priceQuarterly,
    required this.priceYearly,
    required this.features,
    this.isFeatured = false,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      priceMonthly: json['price_monthly'] ?? 0,
      priceQuarterly: json['price_quarterly'] ?? 0,
      priceYearly: json['price_yearly'] ?? 0,
      features: List<String>.from(json['features'] ?? []),
      isFeatured: json['is_featured'] ?? false,
    );
  }
}
