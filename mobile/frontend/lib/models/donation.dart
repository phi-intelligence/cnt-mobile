class DonationInitializeResult {
  final String? authorizationUrl;
  final String? accessCode;
  final String reference;
  final String? publicKey;
  final int amountPesewas;
  final String currency;
  final int recipientUserId;
  final String? contentType;
  final int? contentId;

  const DonationInitializeResult({
    required this.reference,
    this.authorizationUrl,
    this.accessCode,
    this.publicKey,
    required this.amountPesewas,
    this.currency = 'GHS',
    required this.recipientUserId,
    this.contentType,
    this.contentId,
  });

  factory DonationInitializeResult.fromJson(Map<String, dynamic> json) {
    return DonationInitializeResult(
      authorizationUrl: json['authorization_url'] as String?,
      accessCode: json['access_code'] as String?,
      reference: json['reference'] as String? ?? '',
      publicKey: json['public_key'] as String?,
      amountPesewas: json['amount_pesewas'] as int? ?? 0,
      currency: (json['currency'] as String? ?? 'GHS').toUpperCase(),
      recipientUserId: json['recipient_user_id'] as int? ?? 0,
      contentType: json['content_type'] as String?,
      contentId: json['content_id'] as int?,
    );
  }

  String get formattedAmount {
    final major = amountPesewas / 100;
    if (major == major.roundToDouble()) {
      return '$currency ${major.toStringAsFixed(0)}';
    }
    return '$currency ${major.toStringAsFixed(2)}';
  }
}

class DonationVerifyResult {
  final String status;
  final int? donationId;

  const DonationVerifyResult({
    required this.status,
    this.donationId,
  });

  factory DonationVerifyResult.fromJson(Map<String, dynamic> json) {
    return DonationVerifyResult(
      status: json['status'] as String? ?? 'unknown',
      donationId: json['donation_id'] as int?,
    );
  }

  bool get isSuccess =>
      status == 'success' || status == 'already_recorded';
}

class DonationEligibility {
  final bool acceptsDonations;
  final int recipientUserId;
  final String? contentType;
  final int? contentId;

  const DonationEligibility({
    required this.acceptsDonations,
    required this.recipientUserId,
    this.contentType,
    this.contentId,
  });

  factory DonationEligibility.fromJson(Map<String, dynamic> json) {
    return DonationEligibility(
      acceptsDonations: json['accepts_donations'] as bool? ?? false,
      recipientUserId: json['recipient_user_id'] as int? ?? 0,
      contentType: json['content_type'] as String?,
      contentId: json['content_id'] as int?,
    );
  }
}

class DonationParty {
  final int? id;
  final String name;
  final String? avatar;
  final String? email;

  const DonationParty({
    required this.name,
    this.id,
    this.avatar,
    this.email,
  });

  factory DonationParty.fromJson(Map<String, dynamic> json) {
    return DonationParty(
      id: json['id'] as int?,
      name: json['name'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
    );
  }
}

class DonationHistoryItem {
  final int id;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final String? contentType;
  final int? contentId;
  final String? contentTitle;
  final String? reference;
  final String? provider;
  final DonationParty? donor;
  final DonationParty? recipient;

  const DonationHistoryItem({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.contentType,
    this.contentId,
    this.contentTitle,
    this.reference,
    this.provider,
    this.donor,
    this.recipient,
  });

  factory DonationHistoryItem.fromJson(Map<String, dynamic> json) {
    return DonationHistoryItem(
      id: json['id'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String? ?? 'GHS').toUpperCase(),
      status: json['status'] as String? ?? 'unknown',
      createdAt: _parseDate(json['created_at']),
      contentType: json['content_type'] as String?,
      contentId: json['content_id'] as int?,
      contentTitle: json['content_title'] as String?,
      reference: json['reference'] as String?,
      provider: json['provider'] as String?,
      donor: json['donor'] is Map<String, dynamic>
          ? DonationParty.fromJson(json['donor'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] is Map<String, dynamic>
          ? DonationParty.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
    );
  }

  String get formattedAmount {
    if (amount == amount.roundToDouble()) {
      return '$currency ${amount.toStringAsFixed(0)}';
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class DonationHistoryPage {
  final List<DonationHistoryItem> donations;
  final int total;
  final double? totalAmount;

  const DonationHistoryPage({
    required this.donations,
    required this.total,
    this.totalAmount,
  });

  factory DonationHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawDonations = json['donations'];
    final items = rawDonations is List
        ? rawDonations
            .whereType<Map<String, dynamic>>()
            .map(DonationHistoryItem.fromJson)
            .toList()
        : <DonationHistoryItem>[];

    return DonationHistoryPage(
      donations: items,
      total: json['total'] as int? ?? items.length,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
    );
  }

  bool get hasMore => donations.length < total;
}

/// Backend defaults from DONATION_MIN_PESEWAS / DONATION_MAX_PESEWAS.
class DonationAmountLimits {
  static const int minPesewas = 100;
  static const int maxPesewas = 500000;
  static const double minGhs = minPesewas / 100;
  static const double maxGhs = maxPesewas / 100;
  static const List<double> presetGhs = [5, 10, 20, 50];

  static String? validateGhsAmount(double? amount) {
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount';
    }
    if (amount < minGhs) {
      return 'Minimum donation is ${minGhs.toStringAsFixed(0)} GHS';
    }
    if (amount > maxGhs) {
      return 'Maximum donation is ${maxGhs.toStringAsFixed(0)} GHS';
    }
    return null;
  }
}
