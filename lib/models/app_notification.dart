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
}
