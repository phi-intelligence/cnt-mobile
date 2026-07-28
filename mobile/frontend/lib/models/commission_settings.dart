class CommissionSettings {
  final int id;
  final String commissionType;
  final double commissionPercentage;
  final double commissionFixedAmount;
  final bool isActive;
  final DateTime? updatedAt;
  final int? updatedBy;
  final DateTime? createdAt;

  CommissionSettings({
    required this.id,
    required this.commissionType,
    required this.commissionPercentage,
    required this.commissionFixedAmount,
    required this.isActive,
    this.updatedAt,
    this.updatedBy,
    this.createdAt,
  });

  factory CommissionSettings.fromJson(Map<String, dynamic> json) {
    return CommissionSettings(
      id: json['id'] as int? ?? 0,
      commissionType: json['commission_type'] as String? ?? 'percentage',
      commissionPercentage:
          (json['commission_percentage'] as num?)?.toDouble() ?? 0.0,
      commissionFixedAmount:
          (json['commission_fixed_amount'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      updatedBy: json['updated_by'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commission_type': commissionType,
      'commission_percentage': commissionPercentage,
      'commission_fixed_amount': commissionFixedAmount,
      'is_active': isActive,
    };
  }

  String get commissionDescription {
    if (!isActive) return 'Commission Disabled';

    switch (commissionType) {
      case 'percentage':
        return '${commissionPercentage.toStringAsFixed(1)}%';
      case 'fixed':
        return 'GHS ${commissionFixedAmount.toStringAsFixed(2)}';
      case 'percentage_plus_fixed':
        return '${commissionPercentage.toStringAsFixed(1)}% + GHS ${commissionFixedAmount.toStringAsFixed(2)}';
      default:
        return 'Unknown';
    }
  }
}
