class StudyCycle {
  final String id;
  final String name; // e.g., "1º Ciclo", "Mestrado"
  final String institutionId;

  StudyCycle({
    required this.id,
    required this.name,
    required this.institutionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'institutionId': institutionId,
    };
  }

  factory StudyCycle.fromMap(Map<String, dynamic> map) {
    return StudyCycle(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      institutionId: map['institutionId'] ?? '',
    );
  }
}

class Course {
  final String id;
  final String name;
  final String studyCycleId;
  final String institutionId;
  final List<String> subjectIds;

  Course({
    required this.id,
    required this.name,
    required this.studyCycleId,
    required this.institutionId,
    this.subjectIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'studyCycleId': studyCycleId,
      'institutionId': institutionId,
      'subjectIds': subjectIds,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      studyCycleId: map['studyCycleId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      subjectIds: List<String>.from(map['subjectIds'] ?? []),
    );
  }
}
