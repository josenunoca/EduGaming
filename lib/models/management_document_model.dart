import 'package:uuid/uuid.dart';

enum ManagementDocumentOwnerType {
  institution,
  studyCycle,
  organ,
  teacher // Added for individual teacher documents/contracts
}

enum ManagementDocumentStatus { pending, signing, completed, rejected }

class SignatureEntry {
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String signatureType; // 'biometric' | 'citizen_card' | 'electronic'
  final String? ipAddress;

  SignatureEntry({
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.signatureType,
    this.ipAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp.toIso8601String(),
      'signatureType': signatureType,
      'ipAddress': ipAddress,
    };
  }

  factory SignatureEntry.fromMap(Map<String, dynamic> map) {
    return SignatureEntry(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      signatureType: map['signatureType'] ?? 'electronic',
      ipAddress: map['ipAddress'],
    );
  }
}

class ManagementDocument {
  final String id;
  final String ownerId;
  final ManagementDocumentOwnerType ownerType;
  final String title;
  final String url;
  final String fileType; // 'pdf', 'doc', 'image', etc.
  final String
      category; // 'constitution', 'approval', 'minutes', 'contract', 'other'
  final String createdBy;
  final DateTime createdAt;
  final List<String> requiredSignerIds;
  final List<SignatureEntry> signatures;
  final ManagementDocumentStatus status;

  ManagementDocument({
    required this.id,
    required this.ownerId,
    required this.ownerType,
    required this.title,
    required this.url,
    required this.fileType,
    required this.category,
    required this.createdBy,
    required this.createdAt,
    this.requiredSignerIds = const [],
    this.signatures = const [],
    this.status = ManagementDocumentStatus.pending,
  });

  bool get isFullySigned =>
      signatures.length >= requiredSignerIds.length &&
      requiredSignerIds.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerType': ownerType.name,
      'title': title,
      'url': url,
      'fileType': fileType,
      'category': category,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'requiredSignerIds': requiredSignerIds,
      'signatures': signatures.map((s) => s.toMap()).toList(),
      'status': status.name,
    };
  }

  factory ManagementDocument.fromMap(Map<String, dynamic> map) {
    return ManagementDocument(
      id: map['id'] ?? const Uuid().v4(),
      ownerId: map['ownerId'] ?? '',
      ownerType: ManagementDocumentOwnerType.values.firstWhere(
        (e) => e.name == map['ownerType'],
        orElse: () => ManagementDocumentOwnerType.institution,
      ),
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      fileType: map['fileType'] ?? 'pdf',
      category: map['category'] ?? 'other',
      createdBy: map['createdBy'] ?? '',
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      requiredSignerIds: List<String>.from(map['requiredSignerIds'] ?? []),
      signatures: (map['signatures'] as List? ?? [])
          .map((s) => SignatureEntry.fromMap(s))
          .toList(),
      status: ManagementDocumentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ManagementDocumentStatus.pending,
      ),
    );
  }

  ManagementDocument copyWith({
    List<SignatureEntry>? signatures,
    ManagementDocumentStatus? status,
  }) {
    return ManagementDocument(
      id: id,
      ownerId: ownerId,
      ownerType: ownerType,
      title: title,
      url: url,
      fileType: fileType,
      category: category,
      createdBy: createdBy,
      createdAt: createdAt,
      requiredSignerIds: requiredSignerIds,
      signatures: signatures ?? this.signatures,
      status: status ?? this.status,
    );
  }
}
