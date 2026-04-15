// ignore_for_file: unused_import
import 'package:uuid/uuid.dart';

class MeetingSignature {
  final String userId;
  final String userName;
  final DateTime signedAt;

  MeetingSignature({
    required this.userId,
    required this.userName,
    required this.signedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'signedAt': signedAt.toIso8601String(),
    };
  }

  factory MeetingSignature.fromMap(Map<String, dynamic> map) {
    return MeetingSignature(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      signedAt:
          DateTime.parse(map['signedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class AcademicMeeting {
  final String id;
  final String title;
  final String institutionId;
  final String organId; // e.g., "Conselho Pedagógico"
  final DateTime date;
  final List<String> agendaItemIds; // IDs of Subjects to review
  final List<String> requestedTopicIds; // IDs of CouncilRequests
  final List<String> customAgendaPoints; // Manually added texts
  final String? location;
  final String? minutes; // Atas
  final String? convocationText;
  final bool isConvocationFinalized;
  final bool isFinalized;
  final List<MeetingSignature> signatures;

  AcademicMeeting({
    required this.id,
    required this.title,
    required this.institutionId,
    required this.organId,
    required this.date,
    this.agendaItemIds = const [],
    this.requestedTopicIds = const [],
    this.customAgendaPoints = const [],
    this.location,
    this.minutes,
    this.convocationText,
    this.isConvocationFinalized = false,
    this.isFinalized = false,
    this.signatures = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'institutionId': institutionId,
      'organId': organId,
      'date': date.toIso8601String(),
      'agendaItemIds': agendaItemIds,
      'requestedTopicIds': requestedTopicIds,
      'customAgendaPoints': customAgendaPoints,
      'location': location,
      'minutes': minutes,
      'convocationText': convocationText,
      'isConvocationFinalized': isConvocationFinalized,
      'isFinalized': isFinalized,
      'signatures': signatures.map((s) => s.toMap()).toList(),
    };
  }

  factory AcademicMeeting.fromMap(Map<String, dynamic> map) {
    return AcademicMeeting(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      institutionId: map['institutionId'] ?? '',
      organId: map['organId'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      agendaItemIds: List<String>.from(map['agendaItemIds'] ?? []),
      requestedTopicIds: List<String>.from(map['requestedTopicIds'] ?? []),
      customAgendaPoints: List<String>.from(map['customAgendaPoints'] ?? []),
      location: map['location'],
      minutes: map['minutes'],
      convocationText: map['convocationText'],
      isConvocationFinalized: map['isConvocationFinalized'] ?? false,
      isFinalized: map['isFinalized'] ?? false,
      signatures: (map['signatures'] as List? ?? [])
          .map((s) => MeetingSignature.fromMap(s))
          .toList(),
    );
  }
}
