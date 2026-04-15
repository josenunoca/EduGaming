class InstitutionalDocument {
  final String id;
  final String title;
  final String url;
  final String type; // 'regulation', 'manual', 'proposal'
  final String institutionId;
  final String? organId; // Optional, if related to an organ
  final List<DocumentProposal> proposals;

  InstitutionalDocument({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
    required this.institutionId,
    this.organId,
    this.proposals = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'type': type,
      'institutionId': institutionId,
      'organId': organId,
      'proposals': proposals.map((p) => p.toMap()).toList(),
    };
  }

  factory InstitutionalDocument.fromMap(Map<String, dynamic> map) {
    return InstitutionalDocument(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? 'regulation',
      institutionId: map['institutionId'] ?? '',
      organId: map['organId'],
      proposals: (map['proposals'] as List? ?? [])
          .map((p) => DocumentProposal.fromMap(p))
          .toList(),
    );
  }
}

class DocumentProposal {
  final String id;
  final String userId;
  final String userName;
  final String suggestedText;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime timestamp;

  DocumentProposal({
    required this.id,
    required this.userId,
    required this.userName,
    required this.suggestedText,
    this.status = 'pending',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'suggestedText': suggestedText,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DocumentProposal.fromMap(Map<String, dynamic> map) {
    return DocumentProposal(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      suggestedText: map['suggestedText'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
