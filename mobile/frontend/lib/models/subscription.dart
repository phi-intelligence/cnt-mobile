class SubscriptionPlan {
  final String code;
  final String name;
  final int amountPesewas;
  final String currency;
  final String interval;
  final String? description;

  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.amountPesewas,
    required this.currency,
    required this.interval,
    this.description,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amountPesewas: json['amount_pesewas'] as int? ?? 0,
      currency: (json['currency'] as String? ?? 'GHS').toUpperCase(),
      interval: json['interval'] as String? ?? 'monthly',
      description: json['description'] as String?,
    );
  }

  String get formattedAmount {
    final major = amountPesewas / 100;
    if (major == major.roundToDouble()) {
      return '$currency ${major.toStringAsFixed(0)}';
    }
    return '$currency ${major.toStringAsFixed(2)}';
  }

  String get intervalLabel {
    switch (interval.toLowerCase()) {
      case 'monthly':
        return 'month';
      case 'yearly':
      case 'annually':
        return 'year';
      default:
        return interval;
    }
  }
}

class SubscriptionInfo {
  final int id;
  final String status;
  final String provider;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final SubscriptionPlan? plan;

  const SubscriptionInfo({
    required this.id,
    required this.status,
    required this.provider,
    required this.cancelAtPeriodEnd,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.plan,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    return SubscriptionInfo(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'incomplete',
      provider: json['provider'] as String? ?? 'paystack',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      currentPeriodStart: _parseDate(json['current_period_start']),
      currentPeriodEnd: _parseDate(json['current_period_end']),
      plan: planJson is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(planJson)
          : null,
    );
  }

  bool get isActive => status == 'active' || status == 'non_renewing';

  String get statusLabel {
    switch (status) {
      case 'active':
        return cancelAtPeriodEnd ? 'Active (cancels at period end)' : 'Active';
      case 'non_renewing':
        return 'Active until period end';
      case 'past_due':
        return 'Past due';
      case 'canceled':
        return 'Canceled';
      case 'incomplete':
        return 'Incomplete';
      case 'incomplete_expired':
        return 'Expired';
      default:
        return status;
    }
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

class SubscriptionMe {
  final bool entitled;
  final bool enforcementEnabled;
  final SubscriptionInfo? subscription;
  final SubscriptionPlan? plan;

  const SubscriptionMe({
    required this.entitled,
    required this.enforcementEnabled,
    this.subscription,
    this.plan,
  });

  factory SubscriptionMe.fromJson(Map<String, dynamic> json) {
    final subJson = json['subscription'];
    final planJson = json['plan'];
    return SubscriptionMe(
      entitled: json['entitled'] as bool? ?? false,
      enforcementEnabled: json['enforcement_enabled'] as bool? ?? false,
      subscription: subJson is Map<String, dynamic>
          ? SubscriptionInfo.fromJson(subJson)
          : null,
      plan: planJson is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(planJson)
          : null,
    );
  }

  bool get needsSubscription => enforcementEnabled && !entitled;
}

class SubscriptionInitializeResult {
  final String? authorizationUrl;
  final String? accessCode;
  final String reference;
  final String? publicKey;
  final SubscriptionPlan? plan;

  const SubscriptionInitializeResult({
    required this.reference,
    this.authorizationUrl,
    this.accessCode,
    this.publicKey,
    this.plan,
  });

  factory SubscriptionInitializeResult.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    return SubscriptionInitializeResult(
      authorizationUrl: json['authorization_url'] as String?,
      accessCode: json['access_code'] as String?,
      reference: json['reference'] as String? ?? '',
      publicKey: json['public_key'] as String?,
      plan: planJson is Map<String, dynamic>
          ? SubscriptionPlan.fromJson(planJson)
          : null,
    );
  }
}

class SubscriptionVerifyResult {
  final String status;
  final bool entitled;
  final SubscriptionInfo? subscription;

  const SubscriptionVerifyResult({
    required this.status,
    required this.entitled,
    this.subscription,
  });

  factory SubscriptionVerifyResult.fromJson(Map<String, dynamic> json) {
    final subJson = json['subscription'];
    return SubscriptionVerifyResult(
      status: json['status'] as String? ?? 'unknown',
      entitled: json['entitled'] as bool? ?? false,
      subscription: subJson is Map<String, dynamic>
          ? SubscriptionInfo.fromJson(subJson)
          : null,
    );
  }
}

class SubscriptionCancelResult {
  final String status;
  final bool cancelAtPeriodEnd;
  final bool entitled;
  final SubscriptionInfo? subscription;

  const SubscriptionCancelResult({
    required this.status,
    required this.cancelAtPeriodEnd,
    required this.entitled,
    this.subscription,
  });

  factory SubscriptionCancelResult.fromJson(Map<String, dynamic> json) {
    final subJson = json['subscription'];
    return SubscriptionCancelResult(
      status: json['status'] as String? ?? 'canceled',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? true,
      entitled: json['entitled'] as bool? ?? false,
      subscription: subJson is Map<String, dynamic>
          ? SubscriptionInfo.fromJson(subJson)
          : null,
    );
  }
}
