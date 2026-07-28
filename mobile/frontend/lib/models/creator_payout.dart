class CreatorPayoutBank {
  final int id;
  final String code;
  final String name;
  final String? slug;
  final String? type;
  final String? currency;

  const CreatorPayoutBank({
    required this.id,
    required this.code,
    required this.name,
    this.slug,
    this.type,
    this.currency,
  });

  factory CreatorPayoutBank.fromJson(Map<String, dynamic> json) {
    return CreatorPayoutBank(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      type: json['type'] as String?,
      currency: json['currency'] as String?,
    );
  }
}

class CreatorPayoutStatus {
  final bool acceptsDonations;
  final bool payoutsEnabled;
  final String? provider;
  final String? settlementType;
  final String? settlementBankCode;
  final String? accountNumberLast4;
  final String? businessName;
  final double? percentageCharge;
  final DateTime? verifiedAt;

  const CreatorPayoutStatus({
    required this.acceptsDonations,
    required this.payoutsEnabled,
    this.provider,
    this.settlementType,
    this.settlementBankCode,
    this.accountNumberLast4,
    this.businessName,
    this.percentageCharge,
    this.verifiedAt,
  });

  factory CreatorPayoutStatus.fromJson(Map<String, dynamic> json) {
    return CreatorPayoutStatus(
      acceptsDonations: json['accepts_donations'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      provider: json['provider'] as String?,
      settlementType: json['settlement_type'] as String?,
      settlementBankCode: json['settlement_bank_code'] as String?,
      accountNumberLast4: json['account_number_last4'] as String?,
      businessName: json['business_name'] as String?,
      percentageCharge: (json['percentage_charge'] as num?)?.toDouble(),
      verifiedAt: _parseDate(json['verified_at']),
    );
  }

  bool get isConfigured => acceptsDonations && payoutsEnabled;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class CreatorPayoutOnboardRequest {
  final String settlementType;
  final String settlementBankCode;
  final String accountNumber;
  final String businessName;
  final String primaryContactName;
  final String? primaryContactEmail;
  final String? primaryContactPhone;

  const CreatorPayoutOnboardRequest({
    required this.settlementType,
    required this.settlementBankCode,
    required this.accountNumber,
    required this.businessName,
    required this.primaryContactName,
    this.primaryContactEmail,
    this.primaryContactPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'settlement_type': settlementType,
      'settlement_bank_code': settlementBankCode,
      'account_number': accountNumber,
      'business_name': businessName,
      'primary_contact_name': primaryContactName,
      if (primaryContactEmail != null && primaryContactEmail!.isNotEmpty)
        'primary_contact_email': primaryContactEmail,
      if (primaryContactPhone != null && primaryContactPhone!.isNotEmpty)
        'primary_contact_phone': primaryContactPhone,
    };
  }
}
