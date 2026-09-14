/// Configuration for uploading a Paid Video
class PaidVideoConfig {
  final bool isPaid;
  final int previewPercentage;
  final String priceTier;
  final double priceAmount;
  final double creatorTargetPrice;

  const PaidVideoConfig({
    this.isPaid = false,
    this.previewPercentage = 20,
    this.priceTier = 'paid_video_tier_19',
    this.priceAmount = 19.0,
    this.creatorTargetPrice = 19.0,
  });

  PaidVideoConfig copyWith({
    bool? isPaid,
    int? previewPercentage,
    String? priceTier,
    double? priceAmount,
    double? creatorTargetPrice,
  }) {
    return PaidVideoConfig(
      isPaid: isPaid ?? this.isPaid,
      previewPercentage: previewPercentage ?? this.previewPercentage,
      priceTier: priceTier ?? this.priceTier,
      priceAmount: priceAmount ?? this.priceAmount,
      creatorTargetPrice: creatorTargetPrice ?? this.creatorTargetPrice,
    );
  }

  Map<String, dynamic> toJson() => {
    'isPaid': isPaid,
    'previewPercentage': previewPercentage,
    'priceTier': priceTier,
    'priceAmount': priceAmount,
    'creatorTargetPrice': creatorTargetPrice,
  };

  factory PaidVideoConfig.fromJson(Map<String, dynamic> json) {
    return PaidVideoConfig(
      isPaid: json['isPaid'] == true || json['isPaid'] == 'true',
      previewPercentage: int.tryParse(json['previewPercentage']?.toString() ?? '20') ?? 20,
      priceTier: json['priceTier']?.toString() ?? 'paid_video_tier_19',
      priceAmount: double.tryParse(json['priceAmount']?.toString() ?? '19') ?? 19.0,
      creatorTargetPrice: double.tryParse(json['creatorTargetPrice']?.toString() ?? '19') ?? 19.0,
    );
  }
}
