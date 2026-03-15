class InternalMessage {
  final String id;
  final String senderId;
  final String senderName;
  final List<String> recipientIds;
  final List<String> ccIds;
  final String subject;
  final String body;
  final DateTime timestamp;
  final List<String> readBy;
  final List<String> deletedBy;
  final String category; // 'academic', 'correspondence', 'admin', 'other'
  final String? relatedEntityId; // ID of Subject, Course, etc.

  InternalMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientIds,
    this.ccIds = const [],
    required this.subject,
    required this.body,
    required this.timestamp,
    this.readBy = const [],
    this.deletedBy = const [],
    this.category = 'other',
    this.relatedEntityId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'recipientIds': recipientIds,
      'ccIds': ccIds,
      'subject': subject,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'readBy': readBy,
      'deletedBy': deletedBy,
      'category': category,
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
    };
  }

  factory InternalMessage.fromMap(Map<String, dynamic> map) {
    return InternalMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      recipientIds: List<String>.from(map['recipientIds'] ?? []),
      ccIds: List<String>.from(map['ccIds'] ?? []),
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
      category: map['category'] ?? 'other',
      relatedEntityId: map['relatedEntityId'],
    );
  }
}
