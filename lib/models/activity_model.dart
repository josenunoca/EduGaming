

enum ActivityVisibility { participantsOnly, wholeInstitution, courseSpecific, subjectSpecific, public }

class ActivityResource {
  final String id;
  final String name;
  final String type; // 'human' | 'material'
  final String? role; // for humans
  final int? quantity; // for materials

  ActivityResource({
    required this.id,
    required this.name,
    required this.type,
    this.role,
    this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      if (role != null) 'role': role,
      if (quantity != null) 'quantity': quantity,
    };
  }

  factory ActivityResource.fromMap(Map<String, dynamic> map) {
    return ActivityResource(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'material',
      role: map['role'],
      quantity: map['quantity'],
    );
  }
}

class ActivityParticipant {
  final String id;
  final String name;
  final String email;
  final String role; // 'organizer' | 'participant' | 'guest'
  final String? groupType; // 'institution' | 'course' | 'subject'
  final String? groupId;

  ActivityParticipant({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.groupType,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      if (groupType != null) 'groupType': groupType,
      if (groupId != null) 'groupId': groupId,
    };
  }

  factory ActivityParticipant.fromMap(Map<String, dynamic> map) {
    return ActivityParticipant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'participant',
      groupType: map['groupType'],
      groupId: map['groupId'],
    );
  }
}

class ActivityMedia {
  final String id;
  final String name;
  final String url;
  final String type; // 'document' | 'image' | 'video'
  final ActivityVisibility visibility;
  final DateTime uploadedAt;

  ActivityMedia({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.visibility,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'visibility': visibility.name,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  factory ActivityMedia.fromMap(Map<String, dynamic> map) {
    return ActivityMedia(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? 'document',
      visibility: ActivityVisibility.values.firstWhere(
        (e) => e.name == (map['visibility'] ?? 'participantsOnly'),
        orElse: () => ActivityVisibility.participantsOnly,
      ),
      uploadedAt: DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class InstitutionalActivity {
  final String id;
  final String title;
  final String description;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final List<ActivityResource> resources;
  final List<ActivityParticipant> participants;
  final List<ActivityMedia> media;
  final Map<String, dynamic> indicators; // Qualitative/Quantitative stats
  final String status; // 'planned' | 'ongoing' | 'completed' | 'cancelled'

  InstitutionalActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.resources = const [],
    this.participants = const [],
    this.media = const [],
    this.indicators = const {},
    this.status = 'planned',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'institutionId': institutionId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'resources': resources.map((e) => e.toMap()).toList(),
      'participants': participants.map((e) => e.toMap()).toList(),
      'media': media.map((e) => e.toMap()).toList(),
      'indicators': indicators,
      'status': status,
    };
  }

  factory InstitutionalActivity.fromMap(Map<String, dynamic> map) {
    return InstitutionalActivity(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      institutionId: map['institutionId'] ?? '',
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      resources: (map['resources'] as List? ?? []).map((e) => ActivityResource.fromMap(e)).toList(),
      participants: (map['participants'] as List? ?? []).map((e) => ActivityParticipant.fromMap(e)).toList(),
      media: (map['media'] as List? ?? []).map((e) => ActivityMedia.fromMap(e)).toList(),
      indicators: Map<String, dynamic>.from(map['indicators'] ?? {}),
      status: map['status'] ?? 'planned',
    );
  }
}
