class Classroom {
  final String id;
  final String name; // e.g., "Sala 101"
  final String institutionId;
  final int capacity;
  final List<String> resources; // e.g., ['Projector', 'AC']

  Classroom({
    required this.id,
    required this.name,
    required this.institutionId,
    this.capacity = 30,
    this.resources = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'institutionId': institutionId,
      'capacity': capacity,
      'resources': resources,
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      institutionId: map['institutionId'] ?? '',
      capacity: map['capacity'] ?? 30,
      resources: List<String>.from(map['resources'] ?? []),
    );
  }
}

class TimetableEntry {
  final String id;
  final String? subjectId; // Null if it's a break
  final String? classroomId;
  final String? teacherId;
  final int weekday; // 1-7 (Monday-Sunday)
  final String startTime; // HH:mm
  final int durationMinutes;
  final String institutionId;
  final bool isBreak;
  final String? academicYear;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isClosed;
  final String? customActivityName;

  TimetableEntry({
    required this.id,
    this.subjectId,
    this.classroomId,
    this.teacherId,
    required this.weekday,
    required this.startTime,
    this.durationMinutes = 60,
    required this.institutionId,
    this.isBreak = false,
    this.academicYear,
    this.startDate,
    this.endDate,
    this.isClosed = false,
    this.customActivityName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'classroomId': classroomId,
      'teacherId': teacherId,
      'weekday': weekday,
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'institutionId': institutionId,
      'isBreak': isBreak,
      'academicYear': academicYear,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isClosed': isClosed,
      'customActivityName': customActivityName,
    };
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] ?? '',
      subjectId: map['subjectId'],
      classroomId: map['classroomId'],
      teacherId: map['teacherId'],
      weekday: map['weekday'] ?? 1,
      startTime: map['startTime'] ?? '09:00',
      durationMinutes: map['durationMinutes'] ?? 60,
      institutionId: map['institutionId'] ?? '',
      isBreak: map['isBreak'] ?? false,
      academicYear: map['academicYear'],
      startDate:
          map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      isClosed: map['isClosed'] ?? false,
      customActivityName: map['customActivityName'],
    );
  }
}
