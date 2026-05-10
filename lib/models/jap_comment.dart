class JapComment {
  final int id;
  final String author;
  final String text;
  final DateTime? createdAt;

  const JapComment({
    required this.id,
    required this.author,
    required this.text,
    this.createdAt,
  });

  factory JapComment.fromJson(Map<String, dynamic> json) {
    return JapComment(
      id: json['id'] as int,
      author: json['author'] as String? ?? 'Onbekend',
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}