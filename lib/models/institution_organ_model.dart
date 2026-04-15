import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionOrgan {
  final String id;
  final String name;
  final String description;
  final List<String> memberIds;
  final String? presidentEmail;
  final String? vicePresidentEmail;
  final String institutionId;
  final DateTime createdAt;
  final bool isActive;

  InstitutionOrgan({
    required this.id,
    required this.name,
    required this.description,
    required this.memberIds,
    required this.institutionId,
    this.presidentEmail,
    this.vicePresidentEmail,
    required this.createdAt,
    this.isActive = true,
  });

  factory InstitutionOrgan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstitutionOrgan(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      institutionId: data['institutionId'] ?? '',
      presidentEmail: data['presidentEmail'],
      vicePresidentEmail: data['vicePresidentEmail'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'memberIds': memberIds,
      'institutionId': institutionId,
      'presidentEmail': presidentEmail,
      'vicePresidentEmail': vicePresidentEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

}

class Participant {
  final String name;
  final String email;
  final String
      status; // 'invited', 'attended_manual', 'attended_auto', 'absent'
  final bool isGuest;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  Participant({
    required this.name,
    required this.email,
    required this.status,
    this.isGuest = false,
    this.deliveredAt,
    this.readAt,
  });

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'invited',
      isGuest: map['isGuest'] ?? false,
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'status': status,
      'isGuest': isGuest,
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  Participant copyWith({
    String? name,
    String? email,
    String? status,
    bool? isGuest,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return Participant(
      name: name ?? this.name,
      email: email ?? this.email,
      status: status ?? this.status,
      isGuest: isGuest ?? this.isGuest,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  bool get isPresent => status.contains('attended');
}

class Meeting {
  final String id;
  final String organId;
  final String title;
  final String? agenda;
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? audioUrl;
  final String? transcript;
  final String? minutes;
  final String status; // 'scheduled', 'ongoing', 'recorded', 'finalized'
  final List<Participant> participants;
  final List<String> contextFileUrls;
  final String? contextText;
  final String? location;
  final String? invitationText;
  final String institutionId;

  Meeting({
    required this.id,
    required this.organId,
    required this.title,
    this.agenda,
    required this.date,
    this.startTime,
    this.endTime,
    this.audioUrl,
    this.transcript,
    this.minutes,
    required this.status,
    required this.participants,
    this.contextFileUrls = const [],
    this.contextText,
    this.location,
    this.invitationText,
    required this.institutionId,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      organId: data['organId'] ?? '',
      title: data['title'] ?? 'Reunião sem título',
      agenda: data['agenda'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      audioUrl: data['audioUrl'],
      transcript: data['transcript'],
      minutes: data['minutes'],
      status: data['status'] ?? 'scheduled',
      participants: (data['participants'] as List? ?? [])
          .map((p) => Participant.fromMap(p as Map<String, dynamic>))
          .toList(),
      contextFileUrls: List<String>.from(data['contextFileUrls'] ?? []),
      contextText: data['contextText'],
      location: data['location'],
      invitationText: data['invitationText'],
      institutionId: data['institutionId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organId': organId,
      'title': title,
      'agenda': agenda,
      'date': Timestamp.fromDate(date),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'audioUrl': audioUrl,
      'transcript': transcript,
      'minutes': minutes,
      'status': status,
      'participants': participants.map((p) => p.toMap()).toList(),
      'contextFileUrls': contextFileUrls,
      'contextText': contextText,
      'location': location,
      'invitationText': invitationText,
      'institutionId': institutionId,
    };
  }

  Meeting copyWith({
    String? id,
    String? organId,
    String? title,
    String? agenda,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? audioUrl,
    String? transcript,
    String? minutes,
    String? status,
    List<Participant>? participants,
    List<String>? contextFileUrls,
    String? contextText,
    String? location,
    String? invitationText,
    String? institutionId,
  }) {
    return Meeting(
      id: id ?? this.id,
      organId: organId ?? this.organId,
      title: title ?? this.title,
      agenda: agenda ?? this.agenda,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      audioUrl: audioUrl ?? this.audioUrl,
      transcript: transcript ?? this.transcript,
      minutes: minutes ?? this.minutes,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      contextFileUrls: contextFileUrls ?? this.contextFileUrls,
      contextText: contextText ?? this.contextText,
      location: location ?? this.location,
      invitationText: invitationText ?? this.invitationText,
      institutionId: institutionId ?? this.institutionId,
    );
  }
}
