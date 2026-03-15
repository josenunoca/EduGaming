class LiveSession {
  final String id;
  final String subjectId;
  final String teacherId;
  final String topic;
  final String jitsiRoomName;
  final String status; // 'live' | 'ended'
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, bool> studentPermissions; // userId -> canSpeak, etc.

  LiveSession({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.topic,
    required this.jitsiRoomName,
    required this.status,
    required this.startTime,
    this.endTime,
    this.studentPermissions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'topic': topic,
      'jitsiRoomName': jitsiRoomName,
      'status': status,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'studentPermissions': studentPermissions,
    };
  }

  factory LiveSession.fromMap(Map<String, dynamic> map) {
    return LiveSession(
      id: map['id'] ?? '',
      subjectId: map['subjectId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      topic: map['topic'] ?? '',
      jitsiRoomName: map['jitsiRoomName'] ?? '',
      status: map['status'] ?? 'live',
      startTime:
          DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      studentPermissions:
          Map<String, bool>.from(map['studentPermissions'] ?? {}),
    );
  }
}
