import 'package:cloud_firestore/cloud_firestore.dart';

enum KnowledgeAccessType { all, students, parents, staff, organs, restricted }

/// Status do documento: ativo (usado pela IA em primeiro lugar) ou arquivado (consultado como fallback)
enum DocumentStatus { active, archived }

class InstitutionalKnowledgeDocument {
  final String id;
  final String title;
  final String url;
  final String fileName;
  final String fileType; // 'pdf', 'docx', 'txt'
  final String category; // 'regulation', 'manual', 'procedure', 'faq'
  final DateTime uploadDate;
  final KnowledgeAccessType accessType;
  final List<String> restrictedEmails; // Used if accessType is restricted
  final String? extractedText; // Content for AI grounding
  final String institutionId;
  final bool isActive; // Kept for backwards compat; use documentStatus instead
  final DocumentStatus documentStatus; // 'active' or 'archived'
  final DateTime? validFrom; // Optional: start of validity period
  final DateTime? validUntil; // Optional: end of validity period
  final String? targetSubjectId; // Optional: specific subject target
  final String? targetSubjectName; // Display name of subject
  final String? uploaderUserId; // User ID of creator/teacher

  InstitutionalKnowledgeDocument({
    required this.id,
    required this.title,
    required this.url,
    required this.fileName,
    required this.fileType,
    this.category = 'regulation',
    required this.uploadDate,
    this.accessType = KnowledgeAccessType.all,
    this.restrictedEmails = const [],
    this.extractedText,
    required this.institutionId,
    this.isActive = true,
    this.documentStatus = DocumentStatus.active,
    this.validFrom,
    this.validUntil,
    this.targetSubjectId,
    this.targetSubjectName,
    this.uploaderUserId,
  });

  /// Returns true if the document is currently in its validity window (or has no window set).
  bool get isCurrentlyValid {
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return true;
  }

  InstitutionalKnowledgeDocument copyWith({
    DocumentStatus? documentStatus,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isActive,
    Object? clearValidFrom = _sentinel,
    Object? clearValidUntil = _sentinel,
  }) {
    return InstitutionalKnowledgeDocument(
      id: id,
      title: title,
      url: url,
      fileName: fileName,
      fileType: fileType,
      category: category,
      uploadDate: uploadDate,
      accessType: accessType,
      restrictedEmails: restrictedEmails,
      extractedText: extractedText,
      institutionId: institutionId,
      isActive: isActive ?? this.isActive,
      documentStatus: documentStatus ?? this.documentStatus,
      validFrom: clearValidFrom == _sentinel ? (validFrom ?? this.validFrom) : null,
      validUntil: clearValidUntil == _sentinel ? (validUntil ?? this.validUntil) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'fileName': fileName,
      'fileType': fileType,
      'category': category,
      'uploadDate': Timestamp.fromDate(uploadDate),
      'accessType': accessType.name,
      'restrictedEmails': restrictedEmails,
      'extractedText': extractedText,
      'institutionId': institutionId,
      'isActive': documentStatus == DocumentStatus.active,
      'documentStatus': documentStatus.name,
      'validFrom': validFrom != null ? Timestamp.fromDate(validFrom!) : null,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'targetSubjectId': targetSubjectId,
      'targetSubjectName': targetSubjectName,
      'uploaderUserId': uploaderUserId,
    };
  }

  factory InstitutionalKnowledgeDocument.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseTimestamp(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return null;
    }

    final statusStr = map['documentStatus'] as String?;
    final DocumentStatus status;
    if (statusStr != null) {
      status = DocumentStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => (map['isActive'] == false) ? DocumentStatus.archived : DocumentStatus.active,
      );
    } else {
      status = (map['isActive'] == false) ? DocumentStatus.archived : DocumentStatus.active;
    }

    return InstitutionalKnowledgeDocument(
      id: id,
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? 'pdf',
      category: map['category'] ?? 'regulation',
      uploadDate: (map['uploadDate'] as Timestamp).toDate(),
      accessType: KnowledgeAccessType.values.firstWhere(
        (e) => e.name == map['accessType'],
        orElse: () => KnowledgeAccessType.all,
      ),
      restrictedEmails: List<String>.from(map['restrictedEmails'] ?? []),
      extractedText: map['extractedText'],
      institutionId: map['institutionId'] ?? '',
      isActive: map['isActive'] ?? true,
      documentStatus: status,
      validFrom: parseTimestamp(map['validFrom']),
      validUntil: parseTimestamp(map['validUntil']),
      targetSubjectId: map['targetSubjectId'],
      targetSubjectName: map['targetSubjectName'],
      uploaderUserId: map['uploaderUserId'],
    );
  }
}

// Sentinel for copyWith null-clearing
const _sentinel = Object();
