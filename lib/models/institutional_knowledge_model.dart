import 'package:cloud_firestore/cloud_firestore.dart';

enum KnowledgeAccessType { all, students, parents, staff, organs, restricted }

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
  final bool isActive;

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
  });

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
      'isActive': isActive,
    };
  }

  factory InstitutionalKnowledgeDocument.fromMap(String id, Map<String, dynamic> map) {
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
    );
  }
}
