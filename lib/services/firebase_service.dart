import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../models/internal_message.dart';
import '../models/subject_model.dart';
import '../models/live_session_model.dart';
import '../models/credit_pricing_model.dart';
import '../models/course_model.dart';
import '../models/institutional_organ_model.dart';
import '../models/facility_model.dart';
import '../models/document_model.dart';
import '../models/activity_model.dart';
import '../models/credit_transaction.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- Auth ---
  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      debugPrint('Auth error: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    debugPrint('Google Sign-In logic placeholder');
    return null;
  }

  Future<UserCredential?> signInWithFacebook() async {
    debugPrint('Facebook Sign-In logic placeholder');
    return null;
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser!.updatePassword(newPassword);
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      debugPrint('Registration error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- User Profiles ---
  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  Future<InstitutionModel?> getInstitution(String id) async {
    final doc = await _db.collection('institutions').doc(id).get();
    return doc.exists ? InstitutionModel.fromMap(doc.data()!) : null;
  }

  Future<void> updateInstitutionProfile(
      String id, Map<String, dynamic> data) async {
    await _db.collection('institutions').doc(id).update(data);
  }

  Future<UserModel?> getUserData(String uid) => getUserModel(uid);

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return doc.exists ? UserModel.fromMap(doc.data()!) : null;
    });
  }

  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Stream<List<UserModel>> getUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> updateUserAccess(String uid,
      {bool? isPaymentVerified, bool? hasManualAccess}) async {
    final Map<String, dynamic> data = {};
    if (isPaymentVerified != null) {
      data['isPaymentVerified'] = isPaymentVerified;
    }
    if (hasManualAccess != null) data['hasManualAccess'] = hasManualAccess;

    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).update(data);
    }
  }

  Future<void> updateUserInterests(String uid, List<String> interests) async {
    await _db.collection('users').doc(uid).update({'interests': interests});
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<String> uploadSignature(String uid, Uint8List fileBytes) async {
    final ref = _storage.ref().child('signatures').child('$uid.png');
    await ref.putData(fileBytes);
    return await ref.getDownloadURL();
  }

  Stream<List<UserModel>> getChildrenByParent(String parentId) {
    return _db
        .collection('users')
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Future<void> registerChild(UserModel child) async {
    // Note: We're not using Auth for children here as they are managed by the parent
    // and don't need independent login for now, or use parent login.
    // However, they need a document in the users collection.
    await _db.collection('users').doc(child.id).set(child.toMap());
  }

  // --- Institution Management ---
  Future<void> saveInstitution(InstitutionModel institution, {String? creatorUid}) async {
    await _db
        .collection('institutions')
        .doc(institution.id)
        .set(institution.toMap());
    
    if (creatorUid != null) {
      await _db.collection('users').doc(creatorUid).update({
        'institutionId': institution.id,
      });
    }
  }

  Stream<List<InstitutionModel>> getInstitutions() {
    return _db.collection('institutions').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => InstitutionModel.fromMap(doc.data()))
          .toList();
    });
  }

  Stream<InstitutionModel?> getInstitutionStream(String id) {
    return _db.collection('institutions').doc(id).snapshots().map((doc) {
      return doc.exists ? InstitutionModel.fromMap(doc.data()!) : null;
    });
  }

  Future<void> authorizeProfessor(
      String institutionId, String professorId) async {
    await _db.collection('institutions').doc(institutionId).update({
      'authorizedProfessorIds': FieldValue.arrayUnion([professorId])
    });
  }

  Future<void> linkProfessorToInstitution(
      String professorId, String institutionId) async {
    // 1. Update the user document
    await _db
        .collection('users')
        .doc(professorId)
        .update({'institutionId': institutionId});
    // 2. Update the institution document
    await _db.collection('institutions').doc(institutionId).update({
      'authorizedProfessorIds': FieldValue.arrayUnion([professorId])
    });
  }

  Future<void> addProfessorByEmail(
      String name, String email, String institutionId) async {
    // Check if user exists
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final uid = snapshot.docs.first.id;
      await _db.collection('users').doc(uid).update({
        'role': UserRole.teacher.name,
        'institutionId': institutionId,
      });
      await _db.collection('institutions').doc(institutionId).update({
        'authorizedProfessorIds': FieldValue.arrayUnion([uid])
      });
    } else {
      // Create skeleton user
      final uid = const Uuid().v4();
      final newUser = UserModel(
        id: uid,
        name: name,
        email: email,
        role: UserRole.teacher,
        institutionId: institutionId,
        adConsent: true,
        dataConsent: true,
      );
      await _db.collection('users').doc(uid).set(newUser.toMap());
      await _db.collection('institutions').doc(institutionId).update({
        'authorizedProfessorIds': FieldValue.arrayUnion([uid])
      });
    }
  }

  Future<void> addStudentByEmail(
      String name, String email, String institutionId) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final uid = snapshot.docs.first.id;
      await _db.collection('users').doc(uid).update({
        'institutionId': institutionId,
      });
    } else {
      // Create skeleton student
      final uid = const Uuid().v4();
      final newUser = UserModel(
        id: uid,
        name: name,
        email: email,
        role: UserRole.student,
        institutionId: institutionId,
        adConsent: true,
        dataConsent: true,
      );
      await _db.collection('users').doc(uid).set(newUser.toMap());
    }
  }

  Future<List<UserModel>> searchInstitutionMembers(
      String institutionId, String query) async {
    final snapshot = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((u) =>
            u.name.toLowerCase().contains(query.toLowerCase()) ||
            u.email.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> repairInstitutionLink(String uid, String email) async {
    // 1. Search for institutions where this user's email is the primary email
    final instSnapshot = await _db
        .collection('institutions')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (instSnapshot.docs.isNotEmpty) {
      final instId = instSnapshot.docs.first.id;
      await _db.collection('users').doc(uid).update({'institutionId': instId});
      return;
    }

    // 2. Search for institutions where this user is an authorized professor
    final profSnapshot = await _db
        .collection('institutions')
        .where('authorizedProfessorIds', arrayContains: uid)
        .limit(1)
        .get();

    if (profSnapshot.docs.isNotEmpty) {
      final instId = profSnapshot.docs.first.id;
      await _db.collection('users').doc(uid).update({'institutionId': instId});
    }
  }

  // --- File Storage ---
  Future<String?> uploadContentFile(Uint8List bytes, String fileName) async {
    try {
      final safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
      final ref = _storage.ref().child('subject_contents/$safeName');
      final TaskSnapshot snapshot = await ref.putData(bytes);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload to storage error: $e');
      return null;
    }
  }

  // --- Subject Management ---
  Stream<List<UserModel>> getTeachersByInstitution(String institutionId) {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.teacher.toString().split('.').last)
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Stream<List<Subject>> getSubjectsByTeacher(String teacherId,
      {String? academicYear}) {
    Query query =
        _db.collection('subjects').where('teacherId', isEqualTo: teacherId);
    if (academicYear != null) {
      query = query.where('academicYear', isEqualTo: academicYear);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Subject.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<Subject>> getSubjects({
    String? teacherId,
    String? subjectId,
    String? academicYear,
  }) {
    Query query = _db.collection('subjects');

    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    if (subjectId != null) {
      query = query.where(FieldPath.documentId, isEqualTo: subjectId);
    }
    if (academicYear != null) {
      query = query.where('academicYear', isEqualTo: academicYear);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Subject.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<Subject?> getSubjectStream(String subjectId) {
    return _db.collection('subjects').doc(subjectId).snapshots().map((doc) {
      return doc.exists ? Subject.fromMap(doc.data()!) : null;
    });
  }

  Future<Subject?> getSubject(String subjectId) async {
    final doc = await _db.collection('subjects').doc(subjectId).get();
    return doc.exists ? Subject.fromMap(doc.data()!) : null;
  }

  Future<void> deleteSubjectContent(String subjectId, String contentId) async {
    final doc = await _db.collection('subjects').doc(subjectId).get();
    if (!doc.exists) return;
    final subject = Subject.fromMap(doc.data()!);
    final newContents =
        subject.contents.where((c) => c.id != contentId).toList();
    final newGames = subject.games.where((g) => g.id != contentId).toList();

    // Also remove from evaluation components
    final newEvalComponents = subject.evaluationComponents.map((ec) {
      return EvaluationComponent(
        id: ec.id,
        name: ec.name,
        weight: ec.weight,
        contentIds: ec.contentIds.where((id) => id != contentId).toList(),
      );
    }).toList();

    await _db.collection('subjects').doc(subjectId).update({
      'contents': newContents.map((e) => e.toMap()).toList(),
      'games': newGames.map((e) => e.toMap()).toList(),
      'evaluationComponents': newEvalComponents.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> duplicateSubject(Subject source, String newYear) async {
    final newSubjectId = _db.collection('subjects').doc().id;

    // 1. Fetch and Duplicate AiGames
    final oldGamesSnapshot = await _db
        .collection('ai_games')
        .where('subjectId', isEqualTo: source.id)
        .get();

    Map<String, String> gameIdMap = {};

    for (var doc in oldGamesSnapshot.docs) {
      final oldGame = AiGame.fromMap(doc.data());
      final newGameId = _db.collection('ai_games').doc().id;
      gameIdMap[oldGame.id] = newGameId;

      final duplicatedGame = AiGame(
        id: newGameId,
        title: oldGame.title,
        questions: oldGame.questions,
        type: oldGame.type,
        isAssessment: oldGame.isAssessment,
        subjectId: newSubjectId, // Link to new subject
        sourceContentIds: oldGame.sourceContentIds,
      );
      await saveAiGame(duplicatedGame);
    }

    // 2. Update Subject games list (GameContent references)
    final newGamesList = source.games.map((gc) {
      final newId = gameIdMap[gc.id] ?? gc.id;
      return GameContent(
        id: newId,
        name: gc.name,
        url: gc.url,
        type: gc.type,
        weight: gc.weight,
      );
    }).toList();

    // 3. Duplicate and Reset Evaluation Components
    final newEvalComponents = source.evaluationComponents.map((ec) {
      // Update contentIds if they point to duplicated games
      final updatedContentIds =
          ec.contentIds.map((cid) => gameIdMap[cid] ?? cid).toList();

      return EvaluationComponent(
        id: const Uuid().v4(),
        name: ec.name,
        weight: ec.weight,
        contentIds: updatedContentIds,
        pin: null, // Reset pins
        startTime: null, // Reset dates
        endTime: null,
      );
    }).toList();

    // 4. Create and save the new Subject
    final duplicated = Subject(
      id: newSubjectId,
      name: source.name,
      level: source.level,
      academicYear: newYear,
      teacherId: source.teacherId,
      institutionId: source.institutionId,
      allowedStudentEmails: [], // Reset students list for fresh validation
      contents: source.contents,
      games: newGamesList,
      evaluationComponents: newEvalComponents,
      scientificArea: source.scientificArea,
    );

    await _db.collection('subjects').doc(newSubjectId).set(duplicated.toMap());
  }

  Stream<List<Subject>> getSubjectsByInstitution(String institutionId) {
    return _db
        .collection('subjects')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Subject.fromMap(doc.data())).toList());
  }

  Future<void> saveSubject(Subject subject) async {
    // Check and deduct credits for new subject
    final doc = await _db.collection('subjects').doc(subject.id).get();
    if (!doc.exists) {
      final success = await deductCreditsForAction(
          subject.teacherId, CreditAction.createSubject);
      if (!success) {
        throw Exception('Créditos insuficientes para criar disciplina.');
      }
    }
    await _db.collection('subjects').doc(subject.id).set(subject.toMap());
  }

  Future<void> updateSubject(Subject subject) async {
    await _db.collection('subjects').doc(subject.id).set(subject.toMap());
  }

  // --- Enrollment Management ---
  Future<void> requestEnrollment({
    required UserModel student,
    required String subjectId,
    required String institutionId,
  }) async {
    final enrollment = Enrollment(
      id: '${student.id}_$subjectId',
      userId: student.id,
      studentName: student.name,
      studentEmail: student.email,
      subjectId: subjectId,
      institutionId: institutionId,
      status: student.parentId != null ? 'pending_teacher' : 'pending_admin',
      timestamp: DateTime.now(),
    );
    await _db
        .collection('enrollments')
        .doc(enrollment.id)
        .set(enrollment.toMap());
  }

  Future<void> enrollStudentDirectly({
    required UserModel student,
    required Subject subject,
  }) async {
    final enrollment = Enrollment(
      id: '${student.id}_${subject.id}',
      userId: student.id,
      studentName: student.name,
      studentEmail: student.email,
      subjectId: subject.id,
      institutionId: subject.institutionId,
      status: 'accepted',
      timestamp: DateTime.now(),
    );
    await _db
        .collection('enrollments')
        .doc(enrollment.id)
        .set(enrollment.toMap());
  }

  Stream<List<Enrollment>> getEnrollmentsPendingAdmin() {
    return _db
        .collection('enrollments')
        .where('status', isEqualTo: 'pending_admin')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  Stream<List<Enrollment>> getEnrollmentsForTeacher(String teacherId) {
    return _db
        .collection('enrollments')
        .where('status', isEqualTo: 'pending_teacher')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  Stream<List<Enrollment>> getAcceptedEnrollmentsForTeacher(String teacherId) {
    // Note: In a real app, we'd filter by subjects taught by this teacher.
    // For this prototype, we'll fetch all accepted enrollments and filter if subject.teacherId matches.
    return _db
        .collection('enrollments')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  Stream<List<Enrollment>> getEnrollmentsForStudent(String userId) {
    return _db
        .collection('enrollments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  Stream<List<Enrollment>> getEnrollmentsForSubject(String subjectId) {
    return _db
        .collection('enrollments')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  Future<void> adminApprovePayment(String enrollmentId) async {
    await _db
        .collection('enrollments')
        .doc(enrollmentId)
        .update({'status': 'pending_teacher'});
  }

  Future<void> teacherApproveStudent(String enrollmentId) async {
    await _db
        .collection('enrollments')
        .doc(enrollmentId)
        .update({'status': 'accepted'});
  }

  Future<void> rejectEnrollment(String enrollmentId) async {
    await _db
        .collection('enrollments')
        .doc(enrollmentId)
        .update({'status': 'rejected'});
  }

  Future<void> updateEnrollment(
      String enrollmentId, Map<String, dynamic> data) async {
    await _db.collection('enrollments').doc(enrollmentId).update(data);
  }

  Future<String> uploadCertificate(
      String enrollmentId, Uint8List pdfBytes) async {
    final ref = _storage.ref().child('certificates').child('$enrollmentId.pdf');
    await ref.putData(pdfBytes);
    return await ref.getDownloadURL();
  }

  // --- Payments ---
  Future<void> recordPayment(
      String userId, String subjectId, double amount, String method) async {
    await _db.collection('payments').add({
      'userId': userId,
      'subjectId': subjectId,
      'amount': amount,
      'method': method,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- Marketing & Communication ---
  static List<String> getScientificAreas() {
    return [
      'Artes',
      'Ciências Biológicas',
      'Ciências Exatas e da Terra',
      'Ciências Humanas',
      'Ciências Sociais Aplicadas',
      'Engenharias',
      'Linguística, Letras e Artes',
      'Saúde',
    ];
  }

  Future<List<UserModel>> getFilteredUsersForMarketing({
    UserRole? role,
    String? institutionId,
    List<String>? interests,
    String? educationLevel,
    String? subjectId,
    String? scientificArea,
  }) async {
    Query query = _db.collection('users');

    if (role != null) {
      query = query.where('role', isEqualTo: role.toString().split('.').last);
    }
    if (institutionId != null) {
      query = query.where('institutionId', isEqualTo: institutionId);
    }

    // Firestore has limitations with multiple array-contains or array-contains-any.
    // For interests, we might need to filter client-side if multiple are selected,
    // or just use one for the query.

    final snapshot = await query.get();
    var users = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    // Client-side filtering for complex logic (interests, educationLevel, etc.)
    if (interests != null && interests.isNotEmpty) {
      users = users
          .where((u) => u.interests.any((i) => interests.contains(i)))
          .toList();
    }

    // Note: To filter by subjectId or scientificArea, we'd need to cross-ref with enrollments or subjects.
    // This is a simplified version.

    return users;
  }

  // --- Search Logic ---
  Stream<List<InstitutionModel>> searchInstitutions(String query) {
    return getInstitutions().map((list) => list
        .where((i) =>
            i.name.toLowerCase().contains(query.toLowerCase()) ||
            (i.address.toLowerCase().contains(query.toLowerCase())))
        .toList());
  }

  Stream<List<UserModel>> searchUsers(String query) {
    return getUsers().map((list) => list
        .where((u) =>
            u.name.toLowerCase().contains(query.toLowerCase()) ||
            u.email.toLowerCase().contains(query.toLowerCase()))
        .toList());
  }

  Stream<List<Subject>> searchSubjects(String query, {String? teacherId}) {
    Stream<List<Subject>> stream;
    if (teacherId != null) {
      stream = getSubjectsByTeacher(teacherId);
    } else {
      stream = _db
          .collection('subjects')
          .snapshots()
          .map((s) => s.docs.map((d) => Subject.fromMap(d.data())).toList());
    }

    return stream.map((list) => list
        .where((s) =>
            s.name.toLowerCase().contains(query.toLowerCase()) ||
            s.level.toLowerCase().contains(query.toLowerCase()))
        .toList());
  }

  Stream<List<UserModel>> searchTeacherStudents(
      String teacherId, String query) {
    return getUsers().map((list) => list
        .where((u) =>
            u.role == UserRole.student &&
            (u.name.toLowerCase().contains(query.toLowerCase()) ||
                u.email.toLowerCase().contains(query.toLowerCase())))
        .toList());
    // Note: Real filtering would check if the student is in teacher's subjects.
    // For MVP/UX demonstration, searching global students is acceptable if we label it "Alunos".
  }

  // --- AI Gamification ---
  Future<void> saveAiGame(AiGame game) async {
    await _db.collection('ai_games').doc(game.id).set(game.toMap());
  }

  // --- Monetization & AI Credits ---
  Future<void> updateInstitutionPlan(String institutionId, String plan) async {
    await _db.collection('institutions').doc(institutionId).update({
      'subscriptionPlan': plan,
    });
  }

  Future<void> addAiCredits(String targetId, String type, int amount) async {
    final collection = type == 'user' ? 'users' : 'institutions';
    await _db.collection(collection).doc(targetId).update({
      'aiCredits': FieldValue.increment(amount),
    });
  }

  Future<bool> hasEnoughAiCredits(
      String targetId, String type, int required) async {
    final collection = type == 'user' ? 'users' : 'institutions';
    final doc = await _db.collection(collection).doc(targetId).get();
    if (!doc.exists) return false;
    final credits = doc.data()?['aiCredits'] as int? ?? 0;
    return credits >= required;
  }

  Future<void> deductAiCredits(String targetId, String type, int amount) async {
    final collection = type == 'user' ? 'users' : 'institutions';
    await _db.collection(collection).doc(targetId).update({
      'aiCredits': FieldValue.increment(-amount),
    });

    // Log transaction
    await _db.collection('credit_logs').add({
      'targetId': targetId,
      'type': type,
      'amount': amount,
      'action': 'deduction',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- Credit Pricing ---
  Stream<List<CreditPricing>> getCreditPricingStream() {
    return _db.collection('credit_pricing').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return CreditPricing.getDefaultPricing();
      return snapshot.docs
          .map((doc) => CreditPricing.fromMap(doc.data()))
          .toList();
    });
  }

  Future<void> saveCreditPricing(CreditPricing pricing) async {
    await _db.collection('credit_pricing').doc(pricing.id).set(pricing.toMap());
  }

  Future<bool> deductCreditsForAction(String userId, String action) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;

    final user = UserModel.fromMap(userDoc.data()!);

    // Get pricing for this action
    final pricingDoc = await _db.collection('credit_pricing').doc(action).get();
    CreditPricing pricing;
    if (!pricingDoc.exists) {
      pricing = CreditPricing.getDefaultPricing()
          .firstWhere((p) => p.action == action);
    } else {
      pricing = CreditPricing.fromMap(pricingDoc.data()!);
    }

    final cost = pricing.prices[user.role] ?? 0;
    if (cost <= 0) return true; // Free

    // If user belongs to an institution, deduct from institution
    if (user.institutionId != null) {
      final instDoc =
          await _db.collection('institutions').doc(user.institutionId).get();
      if (instDoc.exists) {
        final instCredits = instDoc.data()?['aiCredits'] as int? ?? 0;
        if (instCredits >= cost) {
          await deductAiCredits(user.institutionId!, 'institution', cost);
          return true;
        }
        // Fallback or fail? User says "os créditos são descontados na instituição"
        return false;
      }
    }

    if (user.aiCredits < cost) return false;

    await deductAiCredits(userId, 'user', cost);
    return true;
  }

  // --- Attendance ---
  Future<void> registerAttendance(Attendance attendance) async {
    await _db
        .collection('attendance')
        .doc(attendance.id)
        .set(attendance.toMap());
  }

  Stream<List<Attendance>> getAttendanceForSession(String sessionId) {
    return _db
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromMap(doc.data()))
            .toList());
  }

  Future<List<Attendance>> getAttendanceForSubject(String subjectId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('subjectId', isEqualTo: subjectId)
        .get();
    return snapshot.docs.map((doc) => Attendance.fromMap(doc.data())).toList();
  }

  Future<bool> hasAlreadyRecordedAttendance(
      String userId, String sessionId) async {
    final doc =
        await _db.collection('attendance').doc('${userId}_$sessionId').get();
    return doc.exists;
  }

  Future<void> deleteAttendance(String userId, String sessionId) async {
    await _db.collection('attendance').doc('${userId}_$sessionId').delete();
  }

  Future<Map<String, dynamic>> getAdminRevenueStats() async {
    // This would ideally be a cloud function or complex aggregation
    // For MVP, we calculate manually from collections
    final institutionsQuery = await _db.collection('institutions').get();
    final enrollmentsQuery = await _db
        .collection('enrollments')
        .where('status', isEqualTo: 'accepted')
        .get();

    int proPlan = 0;
    int enterprisePlan = 0;

    for (var doc in institutionsQuery.docs) {
      final plan = doc.data()['subscriptionPlan'] ?? 'base';
      if (plan == 'pro') proPlan++;
      if (plan == 'enterprise') enterprisePlan++;
    }

    // In a real app, enrollments would have a 'paidPrice' field
    // For now, let's assume a fixed fee or check subject price
    // marketplaceRevenue = ...

    return {
      'proInstitutions': proPlan,
      'enterpriseInstitutions': enterprisePlan,
      'activeEnrollments': enrollmentsQuery.size,
      'estimatedRevenue':
          (proPlan * 49.99) + (enterprisePlan * 199.99), // Mock pricing
    };
  }

  Stream<List<AiGame>> getAiGamesBySubject(String subjectId) {
    return _db
        .collection('ai_games')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AiGame.fromMap(doc.data())).toList());
  }

  // --- Exam Sessions (Security & Real-time Monitor) ---
  Future<void> saveExamSession(ExamSession session) async {
    await _db.collection('exam_sessions').doc(session.id).set(session.toMap());
  }

  Future<ExamSession?> getExamSession(String studentId, String gameId) async {
    final snapshot = await _db
        .collection('exam_sessions')
        .where('studentId', isEqualTo: studentId)
        .where('gameId', isEqualTo: gameId)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ExamSession.fromMap(snapshot.docs.first.data());
  }

  Stream<List<ExamSession>> streamActiveExamSessions(String subjectId) {
    return _db
        .collection('exam_sessions')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((s) => s.docs.map((d) => ExamSession.fromMap(d.data())).toList());
  }

  Future<void> updateExamSessionHeartbeat(
      String sessionId, double score, int questionIndex) async {
    await _db.collection('exam_sessions').doc(sessionId).update({
      'lastHeartbeat': DateTime.now().toIso8601String(),
      'currentScore': score,
      'currentQuestionIndex': questionIndex,
      'status': 'active',
    });
  }

  Future<void> setExamSessionStatus(String sessionId, String status) async {
    await _db.collection('exam_sessions').doc(sessionId).update({
      'status': status,
      'lastHeartbeat': DateTime.now().toIso8601String(),
    });
  }

  Future<void> authorizeExamReentry(String sessionId) async {
    await _db.collection('exam_sessions').doc(sessionId).update({
      'authorizedReentry': true,
      'status': 'active', // Reset to active so they can try again
    });
  }

  Future<void> deleteAiGame(String gameId) async {
    await _db.collection('ai_games').doc(gameId).delete();
  }

  Future<void> saveAiGameResult(AiGameResult result) async {
    await _db.collection('ai_game_results').doc(result.id).set(result.toMap());
  }

  Future<List<AiGameResult>> getGameResults(String gameId) async {
    final snapshot = await _db
        .collection('ai_game_results')
        .where('gameId', isEqualTo: gameId)
        .get();
    return snapshot.docs
        .map((doc) => AiGameResult.fromMap(doc.data()))
        .toList();
  }

  Stream<AiGameStats> getStudentGameStats(String studentId, String gameId,
      {bool? isEvaluation}) {
    Query query = _db
        .collection('ai_game_results')
        .where('studentId', isEqualTo: studentId)
        .where('gameId', isEqualTo: gameId);

    if (isEvaluation != null) {
      query = query.where('isEvaluation', isEqualTo: isEvaluation);
    }

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return AiGameStats(gameId: gameId, playCount: 0, maxScore: 0.0);
      }
      final results = snapshot.docs
          .map(
              (doc) => AiGameResult.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      double maxScore = 0.0;
      for (var r in results) {
        if (r.score > maxScore) maxScore = r.score;
      }
      return AiGameStats(
        gameId: gameId,
        playCount: results.length,
        maxScore: maxScore,
      );
    });
  }

  // --- Grade Adjustments ---
  Future<void> saveGradeAdjustment(StudentGradeAdjustment adjustment) async {
    await _db
        .collection('grade_adjustments')
        .doc(adjustment.id)
        .set(adjustment.toMap());
  }

  Stream<List<StudentGradeAdjustment>> getGradeAdjustments(String subjectId) {
    return _db
        .collection('grade_adjustments')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentGradeAdjustment.fromMap(doc.data()))
            .toList());
  }

  Future<List<AiGameResult>> getAllSubjectGameResults(String subjectId) async {
    final snapshot = await _db
        .collection('ai_game_results')
        .where('subjectId', isEqualTo: subjectId)
        .get();
    return snapshot.docs
        .map((doc) => AiGameResult.fromMap(doc.data()))
        .toList();
  }

  Future<bool> hasEvaluationResults(String subjectId,
      {String? gameId, List<String>? gameIds}) async {
    Query query = _db
        .collection('ai_game_results')
        .where('subjectId', isEqualTo: subjectId)
        .where('isEvaluation', isEqualTo: true);

    if (gameId != null) {
      query = query.where('gameId', isEqualTo: gameId);
    } else if (gameIds != null && gameIds.isNotEmpty) {
      query = query.where('gameId', whereIn: gameIds);
    }

    final snapshot = await query.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  // --- Internal Communication (Messaging) ---

  Future<void> sendInternalMessage(InternalMessage message) async {
    await _db
        .collection('internal_messages')
        .doc(message.id)
        .set(message.toMap());
  }

  Stream<List<InternalMessage>> getInboxStream(String userId) {
    // We combine messages where the user is a direct recipient or CC'd
    return _db.collection('internal_messages').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => InternalMessage.fromMap(doc.data()))
            .where((msg) =>
                (msg.recipientIds.contains(userId) ||
                    msg.ccIds.contains(userId)) &&
                !msg.deletedBy.contains(userId))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  Stream<List<InternalMessage>> getSentMessagesStream(String userId) {
    return _db
        .collection('internal_messages')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InternalMessage.fromMap(doc.data()))
            .where((msg) => !msg.deletedBy.contains(userId))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  Future<void> markMessageRead(String userId, String messageId) async {
    await _db.collection('internal_messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> deleteMessageForUser(String userId, String messageId) async {
    await _db.collection('internal_messages').doc(messageId).update({
      'deletedBy': FieldValue.arrayUnion([userId])
    });
  }

  // --- Suspension Logic ---

  Future<void> toggleUserSuspension(String uid, bool suspended) async {
    await _db.collection('users').doc(uid).update({'isSuspended': suspended});
  }

  Future<void> toggleInstitutionSuspension(String id, bool suspended) async {
    await _db
        .collection('institutions')
        .doc(id)
        .update({'isSuspended': suspended});
  }

  Future<void> toggleEnrollmentSuspension(
      String enrollmentId, bool suspended) async {
    await _db
        .collection('enrollments')
        .doc(enrollmentId)
        .update({'isSuspended': suspended});
  }

  // --- Live Session Logic ---

  Future<void> startLiveSession(LiveSession session) async {
    await _db.collection('live_sessions').doc(session.id).set(session.toMap());
  }

  Future<void> endLiveSession(String sessionId) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'status': 'ended',
      'endTime': DateTime.now().toIso8601String(),
    });
  }

  Stream<LiveSession?> getActiveSessionStream(String subjectId) {
    return _db
        .collection('live_sessions')
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: 'live')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return LiveSession.fromMap(snapshot.docs.first.data());
    });
  }

  Future<void> updateStudentPermissions(
      String sessionId, Map<String, bool> permissions) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'studentPermissions': permissions,
    });
  }

  // --- Course & Study Cycle Management ---

  Future<void> saveStudyCycle(StudyCycle cycle) async {
    await _db.collection('study_cycles').doc(cycle.id).set(cycle.toMap());
  }

  Stream<List<StudyCycle>> getStudyCycles(String institutionId) {
    return _db
        .collection('study_cycles')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => StudyCycle.fromMap(d.data())).toList());
  }

  Future<void> saveCourse(Course course) async {
    await _db.collection('courses').doc(course.id).set(course.toMap());
  }

  Stream<List<Course>> getCourses(String institutionId) {
    return _db
        .collection('courses')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => Course.fromMap(d.data())).toList());
  }

  // --- Institutional Organ Management ---

  Future<void> saveOrgan(InstitutionalOrgan organ) async {
    await _db.collection('organs').doc(organ.id).set(organ.toMap());
  }

  Stream<List<InstitutionalOrgan>> getOrgans(String institutionId) {
    return _db
        .collection('organs')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => InstitutionalOrgan.fromMap(d.data())).toList());
  }

  Future<void> inviteMemberToOrgan(String organId, OrganMember member) async {
    await _db.collection('organs').doc(organId).update({
      'members': FieldValue.arrayUnion([member.toMap()])
    });

    // Send internal message/invitation
    final msgId = const Uuid().v4();
    await sendInternalMessage(InternalMessage(
      id: msgId,
      senderId: 'SYSTEM',
      senderName: 'EduGaming System',
      recipientIds: [member.email], // In a real app, resolve email to UID if exists
      subject: 'Convite para Órgão Institucional',
      body: 'Foi convidado para fazer parte do órgão "${member.name}" na sua instituição.',
      timestamp: DateTime.now(),
    ));
  }

  // --- Institutional Program Management ---

  Future<void> saveInstitutionalProgram(
      String institutionId, String courseId, String content) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('programs')
        .doc(courseId)
        .set({
      'courseId': courseId,
      'content': content,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<String?> getInstitutionalProgram(
      String institutionId, String courseId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('programs')
        .doc(courseId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          return data?['content'] as String?;
        });
  }

  // --- Facility & Timetable Management ---

  Future<void> saveClassroom(Classroom classroom) async {
    await _db.collection('classrooms').doc(classroom.id).set(classroom.toMap());
  }

  Stream<List<Classroom>> getClassrooms(String institutionId) {
    return _db
        .collection('classrooms')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => Classroom.fromMap(d.data())).toList());
  }

  Future<void> saveTimetableEntry(TimetableEntry entry) async {
    await _db.collection('timetable').doc(entry.id).set(entry.toMap());
  }

  Stream<List<TimetableEntry>> getTimetableForInstitution(String institutionId) {
    return _db
        .collection('timetable')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => TimetableEntry.fromMap(d.data())).toList());
  }

  Stream<List<TimetableEntry>> getTimetableForUser(String userId, UserRole role) {
    // This is complex. For teachers, we match subjectId with subjects where teacherId = userId.
    // For students, we match subjectId with enrollment subjectIds.
    // For simplicity in MVP, we fetch all and filter client-side or add userId/subjectIds to entries.
    return _db.collection('timetable').snapshots().map((s) => s.docs.map((d) => TimetableEntry.fromMap(d.data())).toList());
  }

  // --- Document & AI Minute Management ---

  Future<void> saveDocument(InstitutionalDocument doc) async {
    await _db.collection('institutional_documents').doc(doc.id).set(doc.toMap());
  }

  Stream<List<InstitutionalDocument>> getDocuments(String institutionId) {
    return _db
        .collection('institutional_documents')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => InstitutionalDocument.fromMap(d.data())).toList());
  }

  Future<void> saveMinute(MeetingMinute minute) async {
    await _db.collection('meeting_minutes').doc(minute.id).set(minute.toMap());
  }

  Future<String> generateAiMinute(String transcription) async {
    // Placeholder for AI call
    debugPrint('Generating AI Minute for: $transcription');
    await Future.delayed(const Duration(seconds: 2));
    return "Ata gerada automaticamente: A reunião focou na discussão de... \n\nDecisões tomadas: \n1. Aprovado o novo regulamento. \n2. Definidas as datas dos exames.";
  }

  // --- Activity & Report Management ---

  Future<void> saveActivity(InstitutionalActivity activity) async {
    await _db.collection('activities').doc(activity.id).set(activity.toMap());
  }

  Stream<List<InstitutionalActivity>> getActivities(String institutionId) {
    return _db
        .collection('activities')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => InstitutionalActivity.fromMap(d.data())).toList());
  }

  Future<void> updateActivityMedia(
      String activityId, ActivityMedia mediaItem) async {
    await _db.collection('activities').doc(activityId).update({
      'media': FieldValue.arrayUnion([mediaItem.toMap()])
    });
  }

  Future<void> inviteGroupToActivity(String activityId, String groupType,
      String groupId, List<UserModel> members) async {
    final participants = members
        .map((u) => ActivityParticipant(
              id: u.id,
              name: u.name,
              email: u.email,
              role: 'participant',
              groupType: groupType,
              groupId: groupId,
            ).toMap())
        .toList();

    await _db.collection('activities').doc(activityId).update({
      'participants': FieldValue.arrayUnion(participants)
    });

    // Notify all participants
    final emails = members.map((u) => u.email).toList();
    if (emails.isNotEmpty) {
      await sendInternalMessage(InternalMessage(
        id: const Uuid().v4(),
        senderId: 'SYSTEM',
        senderName: 'EduGaming System',
        recipientIds: emails,
        subject: 'Novo Convite para Atividade',
        body: 'Foi convidado para participar numa nova atividade institucional.',
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<List<UserModel>> getCourseMembers(
      String institutionId, String courseId) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .where('courseId', isEqualTo: courseId)
        .get();
    return users.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<List<UserModel>> getSubjectMembers(
      String institutionId, String subjectId) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .where('enrolledSubjects', arrayContains: subjectId)
        .get();
    return users.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<List<UserModel>> getAllInstitutionMembers(String institutionId) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .get();
    return users.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  // --- Credit Management ---
  Future<void> logCreditTransaction(CreditTransaction tx) async {
    // 1. Save transaction
    await _db.collection('credit_transactions').doc(tx.id).set(tx.toMap());

    // 2. Update institution balance if it's a recharge
    if (tx.type == TransactionType.recharge) {
      await _db.collection('institutions').doc(tx.institutionId).update({
        'aiCredits': FieldValue.increment(tx.amount),
        'totalCreditsRecharged': FieldValue.increment(tx.amount),
      });
    }

    // 3. Update user consumed credits if it's usage
    if (tx.type == TransactionType.usage) {
      await _db.collection('users').doc(tx.userId).update({
        'totalCreditsConsumed': FieldValue.increment(tx.amount),
      });
      // Also decrement from institution pool
      await _db.collection('institutions').doc(tx.institutionId).update({
        'aiCredits': FieldValue.increment(-tx.amount),
      });
    }
  }

  Future<void> setUserCreditLimit(String uid, int? limit) async {
    await _db.collection('users').doc(uid).update({'aiCreditLimit': limit});
  }

  Future<void> setBulkCreditLimit(
      String institutionId, UserRole role, int? limit) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .where('role', isEqualTo: role.name)
        .get();

    final batch = _db.batch();
    for (var doc in users.docs) {
      batch.update(doc.reference, {'aiCreditLimit': limit});
    }
    await batch.commit();
  }

  Stream<List<CreditTransaction>> getInstitutionTransactions(
      String institutionId) {
    return _db
        .collection('credit_transactions')
        .where('institutionId', isEqualTo: institutionId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CreditTransaction.fromMap(d.data())).toList());
  }

  Future<Map<String, List<UserModel>>> getTopConsumptionStats(
      String institutionId) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .get();

    final allUsers = users.docs.map((d) => UserModel.fromMap(d.data())).toList();

    // Teachers
    final teachers = allUsers.where((u) => u.role == UserRole.teacher).toList();
    teachers.sort((a, b) => b.totalCreditsConsumed.compareTo(a.totalCreditsConsumed));

    // Students
    final students = allUsers.where((u) => u.role == UserRole.student).toList();
    students.sort((a, b) => b.totalCreditsConsumed.compareTo(a.totalCreditsConsumed));

    return {
      'top_teachers': teachers.take(3).toList(),
      'bottom_teachers': teachers.reversed.take(3).toList(),
      'top_students': students.take(3).toList(),
      'bottom_students': students.reversed.take(3).toList(),
    };
  }
}
