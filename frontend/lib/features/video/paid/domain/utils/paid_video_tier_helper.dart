class PaidVideoTier {
  final String productId;
  final double price;
  final String label;

  const PaidVideoTier({
    required this.productId,
    required this.price,
    required this.label,
  });

  /// Creator's 80% net share estimation
  double get estimatedCreatorShare => (price * 0.8 * 100).round() / 100.0;
}

class PaidVideoTierHelper {
  static const List<PaidVideoTier> supportedTiers = [
    PaidVideoTier(productId: 'paid_video_tier_19', price: 19.0, label: '₹19'),
    PaidVideoTier(productId: 'paid_video_tier_49', price: 49.0, label: '₹49'),
    PaidVideoTier(productId: 'paid_video_tier_199', price: 199.0, label: '₹199'),
  ];

  static const PaidVideoTier defaultTier =
      PaidVideoTier(productId: 'paid_video_tier_19', price: 19.0, label: '₹19');

  /// Snaps any custom input amount to the closest supported Google Play tier.
  static PaidVideoTier snapToNearestTier(double enteredAmount) {
    if (enteredAmount <= 0) return supportedTiers.first;

    PaidVideoTier closest = supportedTiers.first;
    double minDiff = (enteredAmount - closest.price).abs();

    for (final tier in supportedTiers) {
      final diff = (enteredAmount - tier.price).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = tier;
      }
    }
    return closest;
  }
}
