import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, late, absent, excused }
enum AttendanceType { checkIn, checkOut }
enum AttendanceMethod { manual, qrCode, faceId, bio }

class HRAttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String institutionId;
  final DateTime timestamp;
  final AttendanceType type;
  final AttendanceMethod method;
  final String? photoUrl;
  final String? location;
  final bool verifiedByManager;

  HRAttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.institutionId,
    required this.timestamp,
    required this.type,
    this.method = AttendanceMethod.manual,
    this.photoUrl,
    this.location,
    this.verifiedByManager = false,
  });

  // Helper for compatibility (if needed)
  DateTime get date => timestamp;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'institutionId': institutionId,
    'timestamp': Timestamp.fromDate(timestamp),
    'type': type.name,
    'method': method.name,
    'photoUrl': photoUrl,
    'location': location,
    'verifiedByManager': verifiedByManager,
    'dateStr': "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}",
  };

  factory HRAttendanceRecord.fromMap(Map<String, dynamic> map) => HRAttendanceRecord(
    id: map['id'] ?? '',
    employeeId: map['employeeId'] ?? '',
    employeeName: map['employeeName'] ?? '',
    institutionId: map['institutionId'] ?? '',
    timestamp: (map['timestamp'] as Timestamp).toDate(),
    type: AttendanceType.values.firstWhere((e) => e.name == map['type'], orElse: () => AttendanceType.checkIn),
    method: AttendanceMethod.values.firstWhere((e) => e.name == map['method'], orElse: () => AttendanceMethod.manual),
    photoUrl: map['photoUrl'],
    location: map['location'],
    verifiedByManager: map['verifiedByManager'] ?? false,
  );
}
