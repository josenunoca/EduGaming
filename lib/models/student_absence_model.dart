import 'package:flutter/foundation.dart';

enum StudentAbsenceType {
  sickLeave,
  vacation,
  medicalAppointment,
  familyReason,
  other,
}

class StudentAbsence {
  final String id;
  final String studentId;
  final String studentName;
  final String parentId;
  final String parentName;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final StudentAbsenceType type;
  final String? description;
  final String? proofUrl;
  final String status; // 'reported', 'acknowledged'
  final DateTime createdAt;

  StudentAbsence({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.parentId,
    required this.parentName,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.description,
    this.proofUrl,
    this.status = 'reported',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'parentId': parentId,
      'parentName': parentName,
      'institutionId': institutionId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'type': type.name,
      'description': description,
      'proofUrl': proofUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudentAbsence.fromMap(Map<String, dynamic> map) {
    return StudentAbsence(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? '',
      institutionId: map['institutionId'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      type: StudentAbsenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StudentAbsenceType.other,
      ),
      description: map['description'],
      proofUrl: map['proofUrl'],
      status: map['status'] ?? 'reported',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  bool isDateAbsent(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return (day.isAfter(start.subtract(const Duration(days: 1))) &&
        day.isBefore(end.add(const Duration(days: 1))));
  }
}
