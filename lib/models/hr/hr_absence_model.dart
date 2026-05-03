import 'package:cloud_firestore/cloud_firestore.dart';

enum AbsenceType { sickLeave, unjustified, vacation, insurance, maternity, mourning, justified, other }

class HRAbsence {
  final String id;
  final String employeeId;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final AbsenceType type;
  final String description;
  final bool isPaid;
  final String? medicalCertificateUrl;
  final String status; // pending, approved, rejected

  HRAbsence({
    required this.id,
    required this.employeeId,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.description = '',
    this.isPaid = false,
    this.medicalCertificateUrl,
    this.status = 'pending',
  });

  int get days => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'institutionId': institutionId,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'type': type.name,
    'description': description,
    'isPaid': isPaid,
    'medicalCertificateUrl': medicalCertificateUrl,
    'status': status,
  };

  factory HRAbsence.fromMap(Map<String, dynamic> map) => HRAbsence(
    id: map['id'],
    employeeId: map['employeeId'],
    institutionId: map['institutionId'],
    startDate: (map['startDate'] as Timestamp).toDate(),
    endDate: (map['endDate'] as Timestamp).toDate(),
    type: AbsenceType.values.firstWhere((e) => e.name == map['type']),
    description: map['description'] ?? '',
    isPaid: map['isPaid'] ?? false,
    medicalCertificateUrl: map['medicalCertificateUrl'],
    status: map['status'] ?? 'pending',
  );
}

class HRVacationPlan {
  final String id;
  final String employeeId;
  final String institutionId;
  final int year;
  final List<DateTimeRange> periods;
  final int totalDaysAllowed;
  final int daysUsed;

  HRVacationPlan({
    required this.id,
    required this.employeeId,
    required this.institutionId,
    required this.year,
    this.periods = const [],
    this.totalDaysAllowed = 22,
    this.daysUsed = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'institutionId': institutionId,
    'year': year,
    'totalDaysAllowed': totalDaysAllowed,
    'daysUsed': daysUsed,
    'periods': periods.map((p) => {
      'start': Timestamp.fromDate(p.start),
      'end': Timestamp.fromDate(p.end),
    }).toList(),
  };

  factory HRVacationPlan.fromMap(Map<String, dynamic> map) {
    return HRVacationPlan(
      id: map['id'],
      employeeId: map['employeeId'],
      institutionId: map['institutionId'],
      year: map['year'],
      totalDaysAllowed: map['totalDaysAllowed'] ?? 22,
      daysUsed: map['daysUsed'] ?? 0,
      periods: (map['periods'] as List? ?? []).map((p) => DateTimeRange(
        start: (p['start'] as Timestamp).toDate(),
        end: (p['end'] as Timestamp).toDate(),
      )).toList(),
    );
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
}
