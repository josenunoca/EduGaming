import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/institutional_knowledge_model.dart';
import '../models/user_model.dart';

class InstitutionalKnowledgeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Register a new document in the knowledge base
  Future<void> addDocument(InstitutionalKnowledgeDocument doc) async {
    await _db
        .collection('institutions')
        .doc(doc.institutionId)
        .collection('knowledge_base')
        .doc(doc.id)
        .set(doc.toMap());
  }

  /// Delete a document
  Future<void> deleteDocument(String institutionId, String docId, String url) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('knowledge_base')
        .doc(docId)
        .delete();
    
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // Log or ignore if file already gone
    }
  }

  /// Fetch documents visible to a specific user
  Future<List<InstitutionalKnowledgeDocument>> getVisibleDocuments(
      String institutionId, UserModel user) async {
    final snap = await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('knowledge_base')
        .where('isActive', isEqualTo: true)
        .get();

    final allDocs = snap.docs.map((d) => InstitutionalKnowledgeDocument.fromMap(d.id, d.data())).toList();

    return allDocs.where((doc) {
      // 1. Check "All"
      if (doc.accessType == KnowledgeAccessType.all) return true;

      // 2. Check Restricted Emails
      if (doc.restrictedEmails.contains(user.email)) return true;

      // 3. Check Roles
      switch (doc.accessType) {
        case KnowledgeAccessType.students:
          return user.isStudent;
        case KnowledgeAccessType.parents:
          return user.isParent;
        case KnowledgeAccessType.staff:
          return user.isTeacher || user.isAdmin;
        case KnowledgeAccessType.organs:
          return user.isOrganMember; // Assuming this field exists or checking roles
        default:
          return false;
      }
    }).toList();
  }

  Stream<List<InstitutionalKnowledgeDocument>> streamAllDocuments(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('knowledge_base')
        .snapshots()
        .map((snap) => snap.docs.map((d) => InstitutionalKnowledgeDocument.fromMap(d.id, d.data())).toList());
  }
}
