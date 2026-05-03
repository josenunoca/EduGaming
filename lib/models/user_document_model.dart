class UserDocument {
  final String url;
  final String name;
  final DateTime uploadedAt;

  UserDocument({
    required this.url,
    required this.name,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'name': name,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory UserDocument.fromMap(Map<String, dynamic> map) {
    return UserDocument(
      url: map['url'] ?? '',
      name: map['name'] ?? '',
      uploadedAt: DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
