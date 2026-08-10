import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/institutional_knowledge_model.dart';
import '../models/user_model.dart';

class InstitutionalKnowledgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference _knowledgeBase(String institutionId) => _db
      .collection('institutions')
      .doc(institutionId)
      .collection('knowledge_base');

  /// Register a new document in the knowledge base
  Future<void> addDocument(InstitutionalKnowledgeDocument doc) async {
    await _knowledgeBase(doc.institutionId).doc(doc.id).set(doc.toMap());
  }

  /// Delete a document
  Future<void> deleteDocument(String institutionId, String docId, String url) async {
    await _knowledgeBase(institutionId).doc(docId).delete();

    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // Log or ignore if file already gone
    }
  }

  /// Update the status (active / archived) and optionally the validity window.
  Future<void> updateDocumentStatus(
    String institutionId,
    String docId, {
    required DocumentStatus status,
    DateTime? validFrom,
    DateTime? validUntil,
    bool clearValidFrom = false,
    bool clearValidUntil = false,
  }) async {
    final data = <String, dynamic>{
      'documentStatus': status.name,
      'isActive': status == DocumentStatus.active,
    };

    if (clearValidFrom) {
      data['validFrom'] = null;
    } else if (validFrom != null) {
      data['validFrom'] = Timestamp.fromDate(validFrom);
    }

    if (clearValidUntil) {
      data['validUntil'] = null;
    } else if (validUntil != null) {
      data['validUntil'] = Timestamp.fromDate(validUntil);
    }

    await _knowledgeBase(institutionId).doc(docId).update(data);
  }

  /// Fetch documents visible to a specific user.
  /// Active documents are returned first; archived are included as a fallback.
  Future<List<InstitutionalKnowledgeDocument>> getVisibleDocuments(
      String institutionId, UserModel user) async {
    final snap = await _knowledgeBase(institutionId).get();

    final allDocs = snap.docs
        .map((d) => InstitutionalKnowledgeDocument.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();

    bool isVisible(InstitutionalKnowledgeDocument doc) {
      // Subject-specific document rule (e.g. evaluation process or activity guide for specific subject)
      if (doc.targetSubjectId != null && doc.targetSubjectId!.isNotEmpty) {
        if (user.isAdmin) return true;
        if (user.isTeacher && doc.uploaderUserId == user.id) return true;
        if (user.isStudent && user.enrolledSubjectIds.contains(doc.targetSubjectId)) return true;
        if (user.isParent) return true; // Parent context filtered via child subjects
        return false;
      }

      if (doc.accessType == KnowledgeAccessType.all) return true;
      if (doc.restrictedEmails.contains(user.email)) return true;
      switch (doc.accessType) {
        case KnowledgeAccessType.students:
          return user.isStudent || user.isParent;
        case KnowledgeAccessType.parents:
          return user.isParent;
        case KnowledgeAccessType.staff:
          return user.isTeacher || user.isAdmin;
        case KnowledgeAccessType.organs:
          return user.isOrganMember;
        default:
          return false;
      }
    }

    final visible = allDocs.where(isVisible).toList();

    // Sort: active first, then archived
    visible.sort((a, b) {
      final aScore = a.documentStatus == DocumentStatus.active ? 0 : 1;
      final bScore = b.documentStatus == DocumentStatus.active ? 0 : 1;
      if (aScore != bScore) return aScore.compareTo(bScore);
      return b.uploadDate.compareTo(a.uploadDate); // newest first within each group
    });

    return visible;
  }

  /// Stream all documents for the management screen
  Stream<List<InstitutionalKnowledgeDocument>> streamAllDocuments(String institutionId) {
    return _knowledgeBase(institutionId).snapshots().map((snap) {
      final docs = snap.docs
          .map((d) => InstitutionalKnowledgeDocument.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      // Sort: active first, then by upload date descending
      docs.sort((a, b) {
        final aScore = a.documentStatus == DocumentStatus.active ? 0 : 1;
        final bScore = b.documentStatus == DocumentStatus.active ? 0 : 1;
        if (aScore != bScore) return aScore.compareTo(bScore);
        return b.uploadDate.compareTo(a.uploadDate);
      });
      return docs;
    });
  }
}
