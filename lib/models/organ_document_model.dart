enum OrganDocumentType {
  minutes,
  regulation,
  legislation,
  other,
}

class OrganDocument {
  final String id;
  final String organId;
  final String title;
  final OrganDocumentType type;
  final String? fileUrl;
  final String? content; // For text worked on within the app
  final bool isVisibleToAllMembers;
  final String createdBy;
  final DateTime createdAt;

  OrganDocument({
    required this.id,
    required this.organId,
    required this.title,
    required this.type,
    this.fileUrl,
    this.content,
    required this.isVisibleToAllMembers,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organId': organId,
      'title': title,
      'type': type.name,
      'fileUrl': fileUrl,
      'content': content,
      'isVisibleToAllMembers': isVisibleToAllMembers,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OrganDocument.fromMap(Map<String, dynamic> map) {
    return OrganDocument(
      id: map['id'] ?? '',
      organId: map['organId'] ?? '',
      title: map['title'] ?? '',
      type: OrganDocumentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OrganDocumentType.other,
      ),
      fileUrl: map['fileUrl'],
      content: map['content'],
      isVisibleToAllMembers: map['isVisibleToAllMembers'] ?? false,
      createdBy: map['createdBy'] ?? '',
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
