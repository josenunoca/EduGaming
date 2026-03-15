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
  final String subjectId;
  final String classroomId;
  final int weekday; // 1-7 (Monday-Sunday)
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String institutionId;

  TimetableEntry({
    required this.id,
    required this.subjectId,
    required this.classroomId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.institutionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'classroomId': classroomId,
      'weekday': weekday,
      'startTime': startTime,
      'endTime': endTime,
      'institutionId': institutionId,
    };
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] ?? '',
      subjectId: map['subjectId'] ?? '',
      classroomId: map['classroomId'] ?? '',
      weekday: map['weekday'] ?? 1,
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '10:00',
      institutionId: map['institutionId'] ?? '',
    );
  }
}
