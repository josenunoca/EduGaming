class ExternalInvitation {
  final String id;
  final String email;
  final String institutionId;
  final String organId;
  final String invitedBy;
  final DateTime createdAt;
  final bool isUsed;

  ExternalInvitation({
    required this.id,
    required this.email,
    required this.institutionId,
    required this.organId,
    required this.invitedBy,
    required this.createdAt,
    this.isUsed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'institutionId': institutionId,
      'organId': organId,
      'invitedBy': invitedBy,
      'createdAt': createdAt.toIso8601String(),
      'isUsed': isUsed,
    };
  }

  factory ExternalInvitation.fromMap(Map<String, dynamic> map) {
    return ExternalInvitation(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      institutionId: map['institutionId'] ?? '',
      organId: map['organId'] ?? '',
      invitedBy: map['invitedBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isUsed: map['isUsed'] ?? false,
    );
  }
}
