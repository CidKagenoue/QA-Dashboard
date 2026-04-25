class NotificationSetting {
  final String module;
  final String type;
  final bool enabled;
  final bool email;

  NotificationSetting({
    required this.module,
    required this.type,
    required this.enabled,
    required this.email,
  });

  factory NotificationSetting.fromJson(Map<String, dynamic> json) {
    return NotificationSetting(
      module: json['module'] as String,
      type: json['type'] as String,
      enabled: json['enabled'] as bool,
      email: json['email'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module,
      'type': type,
      'enabled': enabled,
      'email': email,
    };
  }

  NotificationSetting copyWith({
    String? module,
    String? type,
    bool? enabled,
    bool? email,
  }) {
    return NotificationSetting(
      module: module ?? this.module,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      email: email ?? this.email,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;

  int? get ticketId => _readIntFromMetadata('ticketId');
  int? get accountId => _readIntFromMetadata('accountId');

  String? get source {
    final value = metadata?['source'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return AppNotification(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?)?.trim() ?? 'UNKNOWN',
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      isRead: json['isRead'] == true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] is String
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : null,
    );
  }

  int? _readIntFromMetadata(String key) {
    final value = metadata?[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
