class SupportUserSummary {
  final int id;
  final String? name;
  final String? email;
  final String? avatar;

  SupportUserSummary({
    required this.id,
    this.name,
    this.email,
    this.avatar,
  });

  factory SupportUserSummary.fromJson(Map<String, dynamic> json) {
    return SupportUserSummary(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}

class SupportMessage {
  final int id;
  final String subject;
  final String message;
  final String status;
  final String? adminResponse;
  final int userId;
  final int? adminId;
  final bool adminSeen;
  final bool userSeen;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final SupportUserSummary? user;

  SupportMessage({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.adminResponse,
    required this.userId,
    required this.adminId,
    required this.adminSeen,
    required this.userSeen,
    required this.createdAt,
    required this.updatedAt,
    required this.respondedAt,
    this.user,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as int,
      subject: json['subject'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      adminResponse: json['admin_response'] as String?,
      userId: json['user_id'] as int,
      adminId: json['admin_id'] as int?,
      adminSeen: json['admin_seen'] as bool? ?? false,
      userSeen: json['user_seen'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at'] as String) : null,
      user: json['user'] != null ? SupportUserSummary.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }
}

class SupportStats {
  final int total;
  final int openCount;
  final int unreadAdminCount;
  final int unreadUserCount;

  SupportStats({
    required this.total,
    required this.openCount,
    required this.unreadAdminCount,
    required this.unreadUserCount,
  });

  factory SupportStats.fromJson(Map<String, dynamic> json) {
    return SupportStats(
      total: json['total'] as int? ?? 0,
      openCount: json['open_count'] as int? ?? 0,
      unreadAdminCount: json['unread_admin_count'] as int? ?? 0,
      unreadUserCount: json['unread_user_count'] as int? ?? 0,
    );
  }
}

