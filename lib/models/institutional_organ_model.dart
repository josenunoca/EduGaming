class OrganMember {
  final String email;
  final String name;
  final String? userId; // Optional if already registered
  final Map<String, bool> permissions; // e.g., {'can_approve_minutes': true}

  OrganMember({
    required this.email,
    required this.name,
    this.userId,
    this.permissions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'userId': userId,
      'permissions': permissions,
    };
  }

  factory OrganMember.fromMap(Map<String, dynamic> map) {
    return OrganMember(
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      userId: map['userId'],
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
    );
  }
}

class InstitutionalOrgan {
  final String id;
  final String name; // e.g., "Conselho Pedagógico"
  final String institutionId;
  final List<OrganMember> members;
  final String description;

  InstitutionalOrgan({
    required this.id,
    required this.name,
    required this.institutionId,
    this.members = const [],
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'institutionId': institutionId,
      'members': members.map((m) => m.toMap()).toList(),
      'description': description,
    };
  }

  factory InstitutionalOrgan.fromMap(Map<String, dynamic> map) {
    return InstitutionalOrgan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      institutionId: map['institutionId'] ?? '',
      members: (map['members'] as List? ?? [])
          .map((m) => OrganMember.fromMap(m))
          .toList(),
      description: map['description'] ?? '',
    );
  }
}

class MeetingMinute {
  final String id;
  final String organId;
  final String title;
  final DateTime date;
  final String rawTranscription; // AI input
  final String generatedText; // AI output
  final String status; // 'draft', 'approved'
  final List<String> attendeeEmails;

  MeetingMinute({
    required this.id,
    required this.organId,
    required this.title,
    required this.date,
    this.rawTranscription = '',
    this.generatedText = '',
    this.status = 'draft',
    this.attendeeEmails = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organId': organId,
      'title': title,
      'date': date.toIso8601String(),
      'rawTranscription': rawTranscription,
      'generatedText': generatedText,
      'status': status,
      'attendeeEmails': attendeeEmails,
    };
  }

  factory MeetingMinute.fromMap(Map<String, dynamic> map) {
    return MeetingMinute(
      id: map['id'] ?? '',
      organId: map['organId'] ?? '',
      title: map['title'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      rawTranscription: map['rawTranscription'] ?? '',
      generatedText: map['generatedText'] ?? '',
      status: map['status'] ?? 'draft',
      attendeeEmails: List<String>.from(map['attendeeEmails'] ?? []),
    );
  }
}
