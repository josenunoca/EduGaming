import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart' hide Subject;
import '../models/agenda_item_model.dart';
import '../models/user_model.dart';
import '../models/erp_record_model.dart';
import '../models/management_document_model.dart';
import '../models/institution_model.dart';
import '../models/internal_message.dart';
import '../models/subject_model.dart';
import '../models/questionnaire_model.dart';
import '../models/live_session_model.dart';
import '../models/credit_pricing_model.dart';
import '../models/course_model.dart';
import '../models/institutional_organ_model.dart';
import '../models/institution_organ_model.dart';
import '../models/facility_model.dart';
import '../models/document_model.dart';
import '../models/activity_model.dart';
import '../models/hr/hr_schedule_model.dart';
import '../models/hr/hr_attendance_model.dart';
import '../models/hr/hr_absence_model.dart';
import '../models/hr/hr_evaluation_model.dart';
import '../models/finance/finance_models.dart';
import '../models/school_calendar_model.dart';
import '../models/survey_response_summary_model.dart';
import '../models/course_report_model.dart';
import '../models/assignment_model.dart';
import '../models/curriculum_model.dart';
import '../models/annual_report_draft.dart';
import '../models/invitation_model.dart';
import '../models/organ_document_model.dart';
import '../models/credit_transaction.dart' as ai;
import '../models/meeting_model.dart';
import '../models/council_request_model.dart';
import '../models/assignment_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseFirestore get db => _db;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  UserModel? _cachedUserModel;
  UserModel? get currentUserModel => _cachedUserModel;

  FirebaseService() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        _cachedUserModel = await getUserModel(user.uid);
        _db.collection('users').doc(user.uid).snapshots().listen((doc) {
          if (doc.exists) {
            _cachedUserModel = UserModel.fromMap(doc.data()!);
          }
        });
      } else {
        _cachedUserModel = null;
      }
    });
  }

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

  /// Returns a stream of all UserModels belonging to a given institution.
  Stream<List<UserModel>> getUsersForInstitution(String institutionId) {
    return _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromMap(d.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
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
  
  Future<String> uploadProfilePhoto(String uid, Uint8List fileBytes) async {
    final ref = _storage.ref().child('profile_photos').child('$uid.png');
    await ref.putData(fileBytes);
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoUrl': url});
    return url;
  }

  Future<String> uploadUserDocument(String uid, Uint8List fileBytes, String fileName) async {
    final ref = _storage.ref().child('user_documents').child(uid).child(fileName);
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
  Future<void> saveInstitution(InstitutionModel institution,
      {String? creatorUid}) async {
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

  Future<String> uploadInstitutionLogo(
      String institutionId, Uint8List fileBytes) async {
    final ref = _storage.ref().child('logos').child('$institutionId.png');
    await ref.putData(fileBytes);
    final url = await ref.getDownloadURL();
    await _db
        .collection('institutions')
        .doc(institutionId)
        .update({'logoUrl': url});
    return url;
  }

  Future<String> uploadFile(String filePath, String destination) async {
    final file = File(filePath);
    final ref = _storage.ref().child(destination);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadFileBytes(Uint8List bytes, String destination) async {
    final ref = _storage.ref().child(destination);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
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

  Future<String?> uploadGameMedia(
      String gameId, Uint8List bytes, String fileName) async {
    try {
      final safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
      final ref = _storage.ref().child('ai_games/$gameId/$safeName');
      final TaskSnapshot snapshot = await ref.putData(bytes);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Game media upload error: $e');
      return null;
    }
  }

  Future<String?> uploadMeetingAudio(String meetingId, Uint8List bytes) async {
    try {
      final fileName = 'meeting_$meetingId.m4a';
      final ref = _storage.ref().child('meetings/$meetingId/$fileName');
      final metadata = SettableMetadata(contentType: 'audio/mp4');
      final TaskSnapshot snapshot = await ref.putData(bytes, metadata);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Meeting audio upload error: $e');
      return null;
    }
  }

  /// Logs user feedback on AI responses for institutional knowledge base metrics.
  Future<void> saveAiFeedback({
    required String institutionId,
    required String userId,
    required String userRole,
    required String prompt,
    required String response,
    required int rating,
    Map<String, dynamic>? extraData,
  }) async {
    await _db.collection('ai_feedback').add({
      'institutionId': institutionId,
      'userId': userId,
      'userRole': userRole,
      'prompt': prompt,
      'response': response,
      'rating': rating,
      if (extraData != null) 'extraData': extraData,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- Subject Management ---
  Stream<List<UserModel>> getTeachersByInstitution(String institutionId) {
    return _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) {
      final users =
          snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      return users
          .where((u) =>
              u.role == UserRole.teacher ||
              u.role == UserRole.courseCoordinator)
          .toList();
    });
  }

  Stream<List<UserModel>> getCollaboratorsByInstitution(String institutionId) {
    return _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      return users.where((u) => u.role != UserRole.student && u.role != UserRole.parent).toList();
    });
  }

  Future<void> updateInstitutionDelegation(String institutionId, String moduleKey, List<String> userIds) async {
    await _db.collection('institutions').doc(institutionId).update({
      'delegatedRoles.$moduleKey': userIds,
    });
  }

  // --- School Calendar ---
  Future<void> saveSchoolCalendar(SchoolCalendar calendar) async {
    await _db
        .collection('school_calendars')
        .doc(calendar.id)
        .set(calendar.toMap());
  }

  Future<SchoolCalendar?> getSchoolCalendar(
      String institutionId, String academicYear) async {
    final snapshot = await _db
        .collection('school_calendars')
        .where('institutionId', isEqualTo: institutionId)
        .where('academicYear', isEqualTo: academicYear)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SchoolCalendar.fromMap(snapshot.docs.first.data());
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
      courseId: source.courseId,
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

  Stream<List<Attendance>> getAttendanceStreamForSubject(String subjectId) {
    return _db
        .collection('attendance')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromMap(doc.data()))
            .toList());
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

  Stream<List<AiGame>> getAiGamesBySubject(String subjectId,
      {bool publishedOnly = false}) {
    Query query =
        _db.collection('ai_games').where('subjectId', isEqualTo: subjectId);

    if (publishedOnly) {
      query = query.where('isPublished', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => AiGame.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
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

  Stream<List<ExamSession>> streamStudentExamSessions(String studentId, String subjectId) {
    return _db
        .collection('exam_sessions')
        .where('studentId', isEqualTo: studentId)
        .where('subjectId', isEqualTo: subjectId)
        .where('status', isEqualTo: 'active')
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

  Stream<List<AiGameResult>> getAllSubjectGameResultsStream(String subjectId) {
    return _db
        .collection('ai_game_results')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AiGameResult.fromMap(doc.data()))
            .toList());
  }

  Future<double> getGameAverageScore(String gameId) async {
    final snapshot = await _db
        .collection('ai_game_results')
        .where('gameId', isEqualTo: gameId)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['score'] as num? ?? 0).toDouble();
    }
    return total / snapshot.docs.length;
  }

  Future<int> getStudentGameRanking(
      String studentId, String gameId, String academicYear) async {
    final snapshot = await _db
        .collection('ai_game_results')
        .where('gameId', isEqualTo: gameId)
        .where('academicYear', isEqualTo: academicYear)
        .get();

    if (snapshot.docs.isEmpty) return 1;

    final results =
        snapshot.docs.map((doc) => AiGameResult.fromMap(doc.data())).toList();

    // Group by student and find their best result (Best Score, then Min Time)
    final Map<String, AiGameResult> studentBestResults = {};
    for (var r in results) {
      if (!studentBestResults.containsKey(r.studentId)) {
        studentBestResults[r.studentId] = r;
      } else {
        final currentBest = studentBestResults[r.studentId]!;
        if (r.score > currentBest.score) {
          studentBestResults[r.studentId] = r;
        } else if (r.score == currentBest.score) {
          // Tie-break by time (faster is better)
          final rTime = r.timeTakenSeconds ?? double.infinity;
          final currentBestTime =
              currentBest.timeTakenSeconds ?? double.infinity;
          if (rTime < currentBestTime) {
            studentBestResults[r.studentId] = r;
          }
        }
      }
    }

    final sortedBest = studentBestResults.values.toList()
      ..sort((a, b) {
        // Sort by score DESC
        int scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;

        // Tie-break by timeTakenSeconds ASC (faster = lower time = better/first)
        double aTime = a.timeTakenSeconds ?? double.infinity;
        double bTime = b.timeTakenSeconds ?? double.infinity;
        return aTime.compareTo(bTime);
      });

    int rank = sortedBest.indexWhere((r) => r.studentId == studentId) + 1;
    return rank > 0 ? rank : 1;
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

  Stream<List<InternalMessage>> getMessagesByCategory(String userId, String category) {
    return _db
        .collection('internal_messages')
        .where('recipientIds', arrayContains: userId)
        .where('category', isEqualTo: category)
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

  Future<StudyCycle?> getStudyCycle(String cycleId) async {
    final doc = await _db.collection('study_cycles').doc(cycleId).get();
    return doc.exists ? StudyCycle.fromMap(doc.data()!) : null;
  }

  Stream<List<StudyCycle>> getStudyCycles(String institutionId) {
    return _db
        .collection('study_cycles')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs.map((d) => StudyCycle.fromMap(d.data())).toList());
  }

  Future<void> deleteStudyCycle(String cycleId) async {
    // 1. Get all courses associated with this cycle
    final coursesSnap = await _db
        .collection('courses')
        .where('studyCycleId', isEqualTo: cycleId)
        .get();

    final courseIds = coursesSnap.docs.map((d) => d.id).toList();

    // 2. Check if any of these courses have subjects
    if (courseIds.isNotEmpty) {
      // Handle Firestore whereIn limit (30)
      for (var i = 0; i < courseIds.length; i += 30) {
        final end = (i + 30 < courseIds.length) ? i + 30 : courseIds.length;
        final chunk = courseIds.sublist(i, end);

        final subjectsSnap = await _db
            .collection('subjects')
            .where('courseId', whereIn: chunk)
            .limit(1)
            .get();

        if (subjectsSnap.docs.isNotEmpty) {
          throw Exception(
              'Não é possível anular o ciclo: existem disciplinas associadas aos seus cursos.');
        }
      }
    }

    // 3. No subjects found, proceed with batch deletion
    final batch = _db.batch();

    // Delete associated courses
    for (var doc in coursesSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete the study cycle itself
    batch.delete(_db.collection('study_cycles').doc(cycleId));

    await batch.commit();
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

  Future<void> deleteCourse(String courseId) async {
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    if (!courseDoc.exists) return;

    final course = Course.fromMap(courseDoc.data()!);
    if (course.subjectIds.isNotEmpty) {
      throw Exception(
          'Não é possível anular o curso: existem disciplinas associadas.');
    }
    await _db.collection('courses').doc(courseId).delete();
  }

  Future<void> deleteAcademicYear(String courseId, String year) async {
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    if (!courseDoc.exists) return;

    final course = Course.fromMap(courseDoc.data()!);

    // Check if any subject linked to this course is in this year
    for (String subId in course.subjectIds) {
      final subDoc = await _db.collection('subjects').doc(subId).get();
      if (subDoc.exists) {
        final subData = subDoc.data()!;
        if (subData['academicYear'] == year) {
          throw Exception(
              'Não é possível anular o ano: existem disciplinas registadas para $year.');
        }
      }
    }

    final updatedYears = List<String>.from(course.academicYears)..remove(year);
    await _db
        .collection('courses')
        .doc(courseId)
        .update({'academicYears': updatedYears});
  }

  // --- Institutional Organ Management ---

  Future<void> saveOrgan(InstitutionalOrgan organ) async {
    await _db
        .collection('institutional_organs')
        .doc(organ.id)
        .set(organ.toMap());
  }

  Stream<List<InstitutionalOrgan>> getOrgans(String institutionId) {
    return getInstitutionalOrgans(institutionId);
  }

  Future<void> updateOrgan(String organId, Map<String, dynamic> data) async {
    await _db.collection('institutional_organs').doc(organId).update(data);
  }

  Future<void> inviteMemberToOrgan(String organId, OrganMember member) async {
    await _db.collection('institutional_organs').doc(organId).update({
      'members': FieldValue.arrayUnion([member.toMap()])
    });

    // Send internal message/invitation
    final msgId = const Uuid().v4();
    await sendInternalMessage(InternalMessage(
      id: msgId,
      senderId: 'SYSTEM',
      senderName: 'EduGaming System',
      recipientIds: [
        member.email
      ], // In a real app, resolve email to UID if exists
      subject: 'Convite para Órgão Institucional',
      body:
          'Foi convidado para fazer parte do órgão "${member.name}" na sua instituição.',
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

  Future<String?> uploadClassroomImage(String roomId, Uint8List bytes) async {
    try {
      final ref = _storage.ref().child('classrooms').child('$roomId.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _db.collection('classrooms').doc(roomId).update({'imageUrl': url});
      return url;
    } catch (e) {
      debugPrint('Error uploading classroom image: $e');
      return null;
    }
  }

  Stream<List<InstitutionOrgan>> getInstitutionOrgans(String institutionId) {
    return _db
        .collection('organs')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InstitutionOrgan.fromFirestore(doc))
            .toList());
  }

  // --- Document & AI Minute Management ---

  Future<void> saveDocument(InstitutionalDocument doc) async {
    await _db
        .collection('institutional_documents')
        .doc(doc.id)
        .set(doc.toMap());
  }

  Stream<List<InstitutionalDocument>> getDocuments(String institutionId) {
    return _db
        .collection('institutional_documents')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => InstitutionalDocument.fromMap(d.data()))
            .toList());
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


  Future<void> saveActivity(InstitutionalActivity activity) async {
    await _db.collection('activities').doc(activity.id).set(activity.toMap());
  }

  Future<InstitutionalActivity?> getActivityById(String id) async {
    final doc = await _db.collection('activities').doc(id).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return InstitutionalActivity.fromMap(data);
    }
    return null;
  }

  Future<void> updateActivityStatus(String activityId, String status) async {
    await _db.collection('activities').doc(activityId).update({'status': status});
  }

  Future<void> deleteActivity(String activityId) async {
    await _db.collection('activities').doc(activityId).delete();
  }

  Future<void> deleteAllActivities(String institutionId) async {
    final snapshot = await _db
        .collection('activities')
        .where('institutionId', isEqualTo: institutionId)
        .get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteAllActivitiesByGroup(String institutionId, String activityGroup) async {
    final snapshot = await _db
        .collection('activities')
        .where('institutionId', isEqualTo: institutionId)
        .where('activityGroup', isEqualTo: activityGroup)
        .get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<InstitutionalActivity>> getActivities(String institutionId, {
    String? responsibleUserId,
    String? activityGroup,
    String? academicYear,
    String? status,
  }) {
    Query query = _db.collection('activities').where('institutionId', isEqualTo: institutionId);
    
    if (responsibleUserId != null) query = query.where('responsibleUserId', isEqualTo: responsibleUserId);
    if (activityGroup != null) query = query.where('activityGroup', isEqualTo: activityGroup);
    // status filter
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => InstitutionalActivity.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      // Client-side sorting: planned/in-progress first, then completed.
      // Within status, by date ascending (closest first)
      list.sort((a, b) {
        // Status priority: anything not 'completed' comes first
        final aIsCompleted = a.status == 'completed';
        final bIsCompleted = b.status == 'completed';
        
        if (aIsCompleted != bIsCompleted) {
          return aIsCompleted ? 1 : -1;
        }
        
        // Within same status group, sort by startDate
        return a.startDate.compareTo(b.startDate);
      });
      
      return list;
    });
  }

  Stream<List<InstitutionalActivity>> getActivitiesByResponsible(String userId, {String? academicYear}) {
    var query = _db
        .collection('activities')
        .where('responsibleUserId', isEqualTo: userId);
        
    if (academicYear != null) {
      query = query.where('academicYear', isEqualTo: academicYear);
    }

    return query.snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => InstitutionalActivity.fromMap(doc.data())).toList();
          
          list.sort((a, b) {
            final aIsCompleted = a.status == 'completed';
            final bIsCompleted = b.status == 'completed';
            if (aIsCompleted != bIsCompleted) return aIsCompleted ? 1 : -1;
            return a.startDate.compareTo(b.startDate);
          });
          
          return list;
        });
  }

  Future<void> updateActivityMedia(
      String activityId, ActivityMedia mediaItem) async {
    await _db.collection('activities').doc(activityId).update({
      'media': FieldValue.arrayUnion([mediaItem.toMap()])
    });
  }

  Future<void> removeActivityMedia(
      String activityId, ActivityMedia mediaItem) async {
    await _db.collection('activities').doc(activityId).update({
      'media': FieldValue.arrayRemove([mediaItem.toMap()])
    });
    // In a real app, delete from Storage too if needed
  }

  Future<void> bulkRemoveActivityMedia(
      String activityId, List<ActivityMedia> mediaItems) async {
    final mediaMaps = mediaItems.map((e) => e.toMap()).toList();
    await _db.collection('activities').doc(activityId).update({
      'media': FieldValue.arrayRemove(mediaMaps)
    });
  }

  Future<void> duplicateActivity(
      String sourceId, DateTime newStartDate, DateTime newEndDate) async {
    final doc = await _db.collection('activities').doc(sourceId).get();
    if (!doc.exists) return;

    final source = InstitutionalActivity.fromMap(doc.data()!);
    final newId = const Uuid().v4();

    final duplicated = InstitutionalActivity(
      id: newId,
      title: '${source.title} (Cópia)',
      description: source.description,
      institutionId: source.institutionId,
      startDate: newStartDate,
      endDate: newEndDate,
      startTime: source.startTime,
      endTime: source.endTime,
      activityGroup: source.activityGroup,
      resources: source.resources,
      goals: source.goals,
      indicators: source.indicators,
      // participants: [], // Exclude participants as per request
      // media: [], // Exclude media as per request
      participants: const [],
      media: const [],
      status: 'planned',
    );

    await saveActivity(duplicated);
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

    await _db
        .collection('activities')
        .doc(activityId)
        .update({'participants': FieldValue.arrayUnion(participants)});

    // Notify all participants
    final emails = members.map((u) => u.email).toList();
    if (emails.isNotEmpty) {
      await sendInternalMessage(InternalMessage(
        id: const Uuid().v4(),
        senderId: 'SYSTEM',
        senderName: 'EduGaming System',
        recipientIds: emails,
        subject: 'Novo Convite para Atividade',
        body:
            'Foi convidado para participar numa nova atividade institucional.',
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
  Future<void> logCreditTransaction(ai.CreditTransaction tx) async {
    // 1. Save transaction
    await _db.collection('credit_transactions').doc(tx.id).set(tx.toMap());

    // 2. Update institution balance if it's a recharge
    if (tx.type == ai.TransactionType.recharge) {
      await _db.collection('institutions').doc(tx.institutionId).update({
        'aiCredits': FieldValue.increment(tx.amount),
        'totalCreditsRecharged': FieldValue.increment(tx.amount),
      });
    }

    // 3. Update user consumed credits if it's usage
    if (tx.type == ai.TransactionType.usage) {
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
    final query = _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId);

    QuerySnapshot users;
    if (role == UserRole.teacher) {
      users = await query.where('role', whereIn: [
        UserRole.teacher.name,
        UserRole.courseCoordinator.name
      ]).get();
    } else {
      users = await query.where('role', isEqualTo: role.name).get();
    }

    final batch = _db.batch();
    for (var doc in users.docs) {
      batch.update(doc.reference, {'aiCreditLimit': limit});
    }
    await batch.commit();
  }

  Stream<List<ai.CreditTransaction>> getInstitutionTransactions(
      String institutionId) {
    return _db
        .collection('ai_credit_transactions')
        .where('institutionId', isEqualTo: institutionId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ai.CreditTransaction.fromMap(d.data())).toList());
  }

  Future<Map<String, List<UserModel>>> getTopConsumptionStats(
      String institutionId) async {
    final users = await _db
        .collection('users')
        .where('institutionId', isEqualTo: institutionId)
        .get();

    final allUsers =
        users.docs.map((d) => UserModel.fromMap(d.data())).toList();

    // Teachers (including Coordinators)
    final teachers = allUsers
        .where((u) =>
            u.role == UserRole.teacher || u.role == UserRole.courseCoordinator)
        .toList();
    teachers.sort(
        (a, b) => b.totalCreditsConsumed.compareTo(a.totalCreditsConsumed));

    // Students
    final students = allUsers.where((u) => u.role == UserRole.student).toList();
    students.sort(
        (a, b) => b.totalCreditsConsumed.compareTo(a.totalCreditsConsumed));

    return {
      'top_teachers': teachers.take(3).toList(),
      'bottom_teachers': teachers.reversed.take(3).toList(),
      'top_students': students.take(3).toList(),
      'bottom_students': students.reversed.take(3).toList(),
    };
  }

  // --- Course Coordinator and Delegate Assignment ---

  Future<void> assignCourseCoordinator(
      String courseId, String teacherId) async {
    // 1. Update Course
    await _db.collection('courses').doc(courseId).update({
      'coordinatorId': teacherId,
    });
    // 2. Update User role
    await _db.collection('users').doc(teacherId).update({
      'role': UserRole.courseCoordinator.name,
    });
  }

  Future<void> assignClassDelegate(String courseId, String studentId) async {
    await _db.collection('courses').doc(courseId).update({
      'delegateId': studentId,
    });
  }

  Stream<List<UserModel>> getEligibleDelegates(String courseId) {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.student.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Stream<List<Course>> getCoordinatorCourses(String coordinatorId) {
    return _db
        .collection('courses')
        .where('coordinatorId', isEqualTo: coordinatorId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Course.fromMap(doc.data())).toList());
  }

  Stream<List<SyllabusSession>> getSessionsStream(String subjectId) {
    return _db.collection('subjects').doc(subjectId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data()!;
      final sessionsData = data['sessions'] as List<dynamic>? ?? [];
      return sessionsData
          .map((s) => SyllabusSession.fromMap(s as Map<String, dynamic>))
          .toList();
    });
  }

  // --- Audit Login Updates ---

  Future<void> updateSyllabusSessionWithAudit(String subjectId,
      SyllabusSession session, ModificationEntry entry) async {
    final updatedSession = SyllabusSession(
      id: session.id,
      sessionNumber: session.sessionNumber,
      topic: session.topic,
      date: session.date,
      materialIds: session.materialIds,
      bibliography: session.bibliography,
      proposedSummary: session.proposedSummary,
      finalSummary: session.finalSummary,
      isFinalized: session.isFinalized,
      startTime: session.startTime,
      endTime: session.endTime,
      modificationLog: [...session.modificationLog, entry],
    );

    // This requires updating the specific session in the sessions list of the Subject
    final subjectDoc = await _db.collection('subjects').doc(subjectId).get();
    if (!subjectDoc.exists) return;

    final subject = Subject.fromMap(subjectDoc.data()!);
    final sessions = subject.sessions
        .map((s) => s.id == session.id ? updatedSession : s)
        .toList();

    await _db.collection('subjects').doc(subjectId).update({
      'sessions': sessions.map((s) => s.toMap()).toList(),
    });
  }


  // --- Academic Management (Cursos e Programas) ---
  Future<Course?> getCourse(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    return doc.exists ? Course.fromMap(doc.data()!) : null;
  }

  Stream<List<Course>> getCoursesStream(String institutionId) {
    return _db
        .collection('courses')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Course.fromMap(d.data())).toList());
  }

  Future<void> ensureAcademicYear(String courseId) async {
    final course = await getCourse(courseId);
    if (course == null) return;

    final cycle = await getStudyCycle(course.studyCycleId);
    int maxYears = cycle?.durationValue ?? course.durationYears;
    if (cycle?.durationUnit == 'Meses') {
      maxYears = (maxYears / 12).ceil();
    }

    if (course.academicYears.length >= maxYears) {
      throw Exception('Duração máxima do ciclo atingida ($maxYears anos).');
    }

    // Generate next year based on the last one
    String lastYear = course.academicYears.last;
    final parts = lastYear.split('/');
    if (parts.length == 2) {
      final start = int.parse(parts[0]) + 1;
      final end = int.parse(parts[1]) + 1;
      final yearString = "$start/$end";

      if (!course.academicYears.contains(yearString)) {
        final updatedYears = List<String>.from(course.academicYears)
          ..add(yearString);
        await _db
            .collection('courses')
            .doc(courseId)
            .update({'academicYears': updatedYears});
      }
    }
  }

  // --- Timetable Management ---

  Future<void> saveTimetableEntry(TimetableEntry entry) async {
    await _db.collection('timetable_entries').doc(entry.id).set(entry.toMap());
  }

  Future<void> deleteTimetableEntry(String entryId) async {
    await _db.collection('timetable_entries').doc(entryId).delete();
  }

  Future<void> bulkSaveTimetableEntries(List<TimetableEntry> entries) async {
    final batch = _db.batch();
    for (var entry in entries) {
      batch.set(
          _db.collection('timetable_entries').doc(entry.id), entry.toMap());
    }
    await batch.commit();
  }

  Future<void> deleteTimetableEntriesBulk(
    String institutionId, {
    String? classroomId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _db
        .collection('timetable_entries')
        .where('institutionId', isEqualTo: institutionId);

    if (classroomId != null) {
      query = query.where('classroomId', isEqualTo: classroomId);
    }

    final snapshot = await query.get();
    final batch = _db.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final entry = TimetableEntry.fromMap(doc.data());

      bool shouldDelete = true;
      if (startDate != null && endDate != null) {
        if (entry.startDate != null && entry.endDate != null) {
          // Check for overlap
          if (entry.endDate!.isBefore(startDate) ||
              entry.startDate!.isAfter(endDate)) {
            shouldDelete = false;
          }
        }
      }

      if (shouldDelete) {
        batch.delete(doc.reference);
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Stream<List<TimetableEntry>> getTimetableEntriesStream({
    required String institutionId,
    String? academicYear,
    String? teacherId,
    String? classroomId,
    String? subjectId,
    int? weekday,
  }) {
    Query query = _db
        .collection('timetable_entries')
        .where('institutionId', isEqualTo: institutionId);

    if (academicYear != null)
      query = query.where('academicYear', isEqualTo: academicYear);
    if (teacherId != null)
      query = query.where('teacherId', isEqualTo: teacherId);
    if (classroomId != null)
      query = query.where('classroomId', isEqualTo: classroomId);
    if (subjectId != null)
      query = query.where('subjectId', isEqualTo: subjectId);
    if (weekday != null) query = query.where('weekday', isEqualTo: weekday);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map(
            (doc) => TimetableEntry.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<TimetableEntry>> getTimetableForUser(
      String userId, UserRole role) {
    if (role == UserRole.teacher || role == UserRole.courseCoordinator) {
      return getTimetableEntriesStream(
          institutionId: '',
          teacherId:
              userId); // institutionId is broad if empty or we can resolve it
    }
    // For students, we might need a more complex query (where subjectId in enrolledSubjects)
    // For now, return generic entries for their institution
    return _db.collection('timetable_entries').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TimetableEntry.fromMap(doc.data()))
            .toList());
  }

  Future<void> duplicateSyllabus(
      Subject sourceSubject, String targetYear) async {
    final newId = const Uuid().v4();
    final newSubject = Subject(
      id: newId,
      name: sourceSubject.name,
      level: sourceSubject.level,
      academicYear: targetYear,
      teacherId: sourceSubject.teacherId,
      institutionId: sourceSubject.institutionId,
      allowedStudentEmails: sourceSubject.allowedStudentEmails,
      contents: sourceSubject.contents,
      games: sourceSubject.games,
      evaluationComponents: sourceSubject.evaluationComponents,
      scientificArea: sourceSubject.scientificArea,
      programDescription: sourceSubject.programDescription,
      pautaStatus: PautaStatus.draft,
      theoreticalHours: sourceSubject.theoreticalHours,
      theoreticalPracticalHours: sourceSubject.theoreticalPracticalHours,
      practicalHours: sourceSubject.practicalHours,
      otherHours: sourceSubject.otherHours,
      ects: sourceSubject.ects,
      syllabusStatus: SyllabusStatus.provisional,
      sessions: sourceSubject.sessions
          .map((s) => SyllabusSession(
                id: const Uuid().v4(),
                sessionNumber: s.sessionNumber,
                topic: s.topic,
                date: s.date.add(const Duration(days: 365)), // Approximate
                materialIds: s.materialIds,
                bibliography: s.bibliography,
              ))
          .toList(),
      price: sourceSubject.price,
      currency: sourceSubject.currency,
      isMarketplaceEnabled: sourceSubject.isMarketplaceEnabled,
      courseId: sourceSubject.courseId,
    );

    await _db.collection('subjects').doc(newId).set(newSubject.toMap());
  }

  Future<void> duplicateStudyCycle({
    required String sourceCycleId,
    required String newName,
    required String targetAcademicYear,
    required Map<String, String>
        subjectIdToTeacherId, // sourceSubjectId -> newTeacherId
  }) async {
    final batch = _db.batch();

    // 1. Clone StudyCycle
    final newCycleId = const Uuid().v4();
    final newCycle = StudyCycle(
      id: newCycleId,
      name: newName,
      institutionId:
          (await _db.collection('study_cycles').doc(sourceCycleId).get())
                  .data()?['institutionId'] ??
              '',
    );
    batch.set(_db.collection('study_cycles').doc(newCycleId), newCycle.toMap());

    // 2. Clone Courses
    final coursesSnap = await _db
        .collection('courses')
        .where('studyCycleId', isEqualTo: sourceCycleId)
        .get();

    for (var courseDoc in coursesSnap.docs) {
      final sourceCourse = Course.fromMap(courseDoc.data());
      final newCourseId = const Uuid().v4();
      List<String> newSubjectIds = [];

      // 3. Clone Subjects for each Course
      final subjectsSnap = await _db
          .collection('subjects')
          .where('courseId', isEqualTo: sourceCourse.id)
          .get();

      for (var subjectDoc in subjectsSnap.docs) {
        final sourceSubject = Subject.fromMap(subjectDoc.data());
        final newSubjectId = const Uuid().v4();
        newSubjectIds.add(newSubjectId);

        final newSubject = Subject(
          id: newSubjectId,
          name: sourceSubject.name,
          level: sourceSubject.level,
          academicYear: targetAcademicYear,
          teacherId:
              subjectIdToTeacherId[sourceSubject.id] ?? sourceSubject.teacherId,
          institutionId: sourceSubject.institutionId,
          courseId: newCourseId,
          allowedStudentEmails: [], // Reset for new year
          contents: sourceSubject.contents,
          games: sourceSubject.games,
          evaluationComponents: sourceSubject.evaluationComponents,
          scientificArea: sourceSubject.scientificArea,
          programDescription: sourceSubject.programDescription,
          pautaStatus: PautaStatus.draft,
          theoreticalHours: sourceSubject.theoreticalHours,
          theoreticalPracticalHours: sourceSubject.theoreticalPracticalHours,
          practicalHours: sourceSubject.practicalHours,
          otherHours: sourceSubject.otherHours,
          ects: sourceSubject.ects,
          syllabusStatus: SyllabusStatus.provisional,
          sessions: sourceSubject.sessions
              .map((s) => SyllabusSession(
                    id: const Uuid().v4(),
                    sessionNumber: s.sessionNumber,
                    topic: s.topic,
                    date: s.date.add(const Duration(days: 365)),
                    materialIds: s.materialIds,
                    bibliography: s.bibliography,
                  ))
              .toList(),
          price: sourceSubject.price,
          currency: sourceSubject.currency,
          isMarketplaceEnabled: sourceSubject.isMarketplaceEnabled,
        );
        batch.set(
            _db.collection('subjects').doc(newSubjectId), newSubject.toMap());
      }

      final newCourse = Course(
        id: newCourseId,
        name: sourceCourse.name,
        studyCycleId: newCycleId,
        institutionId: sourceCourse.institutionId,
        subjectIds: newSubjectIds,
        academicYears: [targetAcademicYear],
        coordinatorId: sourceCourse.coordinatorId,
        delegateId: null, // Reset for new year
        durationYears: sourceCourse.durationYears,
      );
      batch.set(_db.collection('courses').doc(newCourseId), newCourse.toMap());
    }

    await batch.commit();
  }

  Future<void> submitSyllabusToCouncil(
      String subjectId, SyllabusStatus nextStatus) async {
    await _db.collection('subjects').doc(subjectId).update({
      'syllabusStatus': nextStatus.name,
    });
  }

  Future<void> approveSyllabus(String subjectId, SyllabusStatus finalStatus,
      String userId, String userName) async {
    final now = DateTime.now();
    final Map<String, dynamic> data = {
      'syllabusStatus': finalStatus.name,
    };

    if (finalStatus == SyllabusStatus.inValidationPedagogical) {
      data['scientificApprovalDate'] = now.toIso8601String();
      data['scientificApprovedBy'] = userName;
    } else if (finalStatus == SyllabusStatus.approved) {
      data['pedagogicalApprovalDate'] = now.toIso8601String();
      data['pedagogicalApprovedBy'] = userName;
      data['pedagogicalSignatures'] = FieldValue.arrayUnion([userId]);
    }

    await _db.collection('subjects').doc(subjectId).update(data);
  }

  // --- Gestão de Conselhos e Pedidos ---

  Future<void> submitCouncilRequest(CouncilRequest request) async {
    await _db
        .collection('council_requests')
        .doc(request.id)
        .set(request.toMap());
  }

  Stream<List<CouncilRequest>> getPendingRequestsByOrgan(String organId) {
    return _db
        .collection('council_requests')
        .where('organId', isEqualTo: organId)
        .where('status', isEqualTo: CouncilRequestStatus.pending.name)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CouncilRequest.fromMap(d.data())).toList());
  }

  Future<void> scheduleMeetingAndNotify(AcademicMeeting meeting) async {
    // 1. Save Meeting
    await _db
        .collection('academic_meetings')
        .doc(meeting.id)
        .set(meeting.toMap());

    // 2. Notify Organ Members
    final organDoc =
        await _db.collection('institutional_organs').doc(meeting.organId).get();
    if (organDoc.exists) {
      final organ = InstitutionalOrgan.fromMap(organDoc.data()!);
      final memberIds =
          organ.members.map((m) => m.userId).whereType<String>().toList();

      if (memberIds.isNotEmpty) {
        final notification = InternalMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'system',
          senderName: 'Gestão Académica',
          recipientIds: memberIds,
          subject: 'Nova Reunião Agendada: ${meeting.title}',
          body:
              'Convocatória para reunião do órgão ${organ.name}.\nData: ${meeting.date}\nLocal: ${meeting.location ?? "Por definir"}',
          timestamp: DateTime.now(),
        );
        await sendInternalMessage(notification);
      }
    }

    // 3. Update associated requests and notify requesters
    for (String requestId in meeting.requestedTopicIds) {
      await _db.collection('council_requests').doc(requestId).update({
        'status': CouncilRequestStatus.inAgenda.name,
        'meetingId': meeting.id,
      });

      final reqDoc =
          await _db.collection('council_requests').doc(requestId).get();
      if (reqDoc.exists) {
        final request = CouncilRequest.fromMap(reqDoc.data()!);
        final notification = InternalMessage(
          id: 'req_${DateTime.now().millisecondsSinceEpoch}_$requestId',
          senderId: 'system',
          senderName: 'Gestão Académica',
          recipientIds: [request.requesterId],
          subject: 'Tema incluído na Ordem de Trabalhos',
          body:
              'O seu pedido "${request.title}" foi incluído na reunião: ${meeting.title}.\nData: ${meeting.date}',
          timestamp: DateTime.now(),
        );
        await sendInternalMessage(notification);
      }
    }
  }

  Stream<List<InstitutionalOrgan>> getInstitutionalOrgans(
      String institutionId) {
    return _db
        .collection('institutional_organs')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => InstitutionalOrgan.fromMap(d.data())).toList());
  }

  Stream<List<AcademicMeeting>> getAcademicMeetings(String institutionId) {
    return _db
        .collection('academic_meetings')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AcademicMeeting.fromMap(d.data())).toList());
  }

  Future<void> sendExternalInvite({
    required String email,
    required String institutionId,
    required String organId,
    required String invitedBy,
  }) async {
    final invite = ExternalInvitation(
      id: _db.collection('invitations').doc().id,
      email: email,
      institutionId: institutionId,
      organId: organId,
      invitedBy: invitedBy,
      createdAt: DateTime.now(),
    );

    await _db.collection('invitations').doc(invite.id).set(invite.toMap());

    // Mock Email Sending
  }

  Future<void> completeExternalInvite(String inviteId, String userId) async {
    final inviteDoc = await _db.collection('invitations').doc(inviteId).get();
    if (!inviteDoc.exists) return;

    final invite = ExternalInvitation.fromMap(inviteDoc.data()!);
    if (invite.isUsed) return;

    // 1. Mark invite as used
    await _db.collection('invitations').doc(inviteId).update({'isUsed': true});

    // 2. Add user to organ members
    final organDoc =
        await _db.collection('institutional_organs').doc(invite.organId).get();
    if (organDoc.exists) {
      final organ = InstitutionalOrgan.fromMap(organDoc.data()!);
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final user = UserModel.fromMap(userDoc.data()!);
        final newMember = OrganMember(
          email: user.email,
          name: user.name,
          userId: userId,
        );

        await _db
            .collection('institutional_organs')
            .doc(invite.organId)
            .update({
          'members': FieldValue.arrayUnion([newMember.toMap()])
        });
      }
    }
  }

  // --- Documentos de Órgãos ---

  Future<void> saveOrganDocument(OrganDocument document) async {
    await _db
        .collection('organ_documents')
        .doc(document.id)
        .set(document.toMap());
  }

  Stream<List<OrganDocument>> getDocumentsForMember(
      String organId, String userId, bool isPresident) {
    if (isPresident) {
      // President sees everything for their organ
      return _db
          .collection('organ_documents')
          .where('organId', isEqualTo: organId)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => OrganDocument.fromMap(d.data())).toList());
    } else {
      // Members see only what is visible to all
      return _db
          .collection('organ_documents')
          .where('organId', isEqualTo: organId)
          .where('isVisibleToAllMembers', isEqualTo: true)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => OrganDocument.fromMap(d.data())).toList());
    }
  }

  Future<String> generateConvocationWithAi(AcademicMeeting meeting) async {
    // Mock AI call
    final agenda = meeting.customAgendaPoints.isNotEmpty
        ? meeting.customAgendaPoints.join('\n- ')
        : 'Análise de temas pendentes';

    return '''
CONVOCATÓRIA DE REUNIÃO

Título: ${meeting.title}
Data: ${meeting.date.toLocal()}
Local: ${meeting.location ?? "Por definir"}

ORDEM DE TRABALHOS:
- $agenda

Solicita-se a comparência de todos os membros.
Este documento foi gerado com assistência de IA.
''';
  }

  Stream<List<Subject>> getSubjectsStreamByCourse(String courseId) {
    return _db
        .collection('subjects')
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Subject.fromMap(doc.data())).toList());
  }

  Future<void> deleteSubject(String subjectId) async {
    await _db.collection('subjects').doc(subjectId).delete();
  }

  // --- Questionnaire System ---

  /// Legacy alias for saveSurvey — ensures both root and institution sub-collections are synced.
  Future<void> saveQuestionnaire(Questionnaire questionnaire) async {
    await saveSurvey(questionnaire);
  }

  Future<void> _notifyParticipantsOfNewSurvey(Questionnaire survey) async {
    final members = await getAllInstitutionMembers(survey.institutionId);
    final recipients = <String>{};

    for (var audience in survey.audiences) {
      if (audience == SurveyAudience.students) {
        recipients.addAll(members.where((u) => u.role == UserRole.student).map((u) => u.id));
      } else if (audience == SurveyAudience.teachers) {
        recipients.addAll(members.where((u) => u.role == UserRole.teacher).map((u) => u.id));
      } else if (audience == SurveyAudience.parents) {
        recipients.addAll(members.where((u) => u.role == UserRole.parent).map((u) => u.id));
      } else if (audience == SurveyAudience.nonTeachingStaff) {
        recipients.addAll(members.where((u) => u.role == UserRole.other).map((u) => u.id));
      }
    }

    // Add individual targets (if they are IDs)
    for (var target in survey.individualTargetIds) {
      if (!target.contains('@')) recipients.add(target);
      else {
        final resolved = members.where((u) => u.email == target).firstOrNull;
        if (resolved != null) recipients.add(resolved.id);
      }
    }

    // Remove excluded
    for (var excl in survey.excludedTargetIds) {
      if (!excl.contains('@')) recipients.remove(excl);
      else {
        final resolved = members.where((u) => u.email == excl).firstOrNull;
        if (resolved != null) recipients.remove(resolved.id);
      }
    }

    if (recipients.isNotEmpty) {
      await sendInstitutionalNotification(
        recipientIds: recipients.toList(),
        title: 'Novo Inquérito: ${survey.title}',
        body: 'Tem um novo inquérito disponível para resposta. O prazo termina em ${DateFormat('dd/MM/yyyy').format(survey.endDate)}.',
        senderName: 'Sistema Institucional',
        category: 'academic_alert',
        relatedEntityId: survey.id,
      );
    }
  }
  Stream<List<Questionnaire>> getQuestionnaires(String institutionId) {
    return _db
        .collection('questionnaires')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Questionnaire.fromMap(doc.data()))
            .toList());
  }

  Stream<List<Questionnaire>> getAvailableQuestionnaires(
    String userId,
    String? userEmail,
    UserRole? role,
    String institutionId,
  ) {
    return _db
        .collection('questionnaires')
        .where('institutionId', isEqualTo: institutionId)
        .where('status', isEqualTo: SurveyStatus.active.name)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Questionnaire.fromMap(doc.data()))
          .where((q) {
        // Broad date check
        if (now.isAfter(q.endDate.add(const Duration(days: 1))) || 
            now.isBefore(q.startDate.subtract(const Duration(hours: 1)))) return false;

        final teacherKeywords = ['teachers', 'teacher', 'docente', 'pessoal docente', 'professor', 'professores'];
        final studentKeywords = ['students', 'student', 'aluno', 'alunos'];

        final roleMatches = q.targetRoles.contains('all') ||
            (role != null && q.targetRoles.contains(role.name)) ||
            (role == UserRole.teacher && q.targetRoles.any((r) => teacherKeywords.contains(r.toLowerCase()))) ||
            (role == UserRole.student && q.targetRoles.any((r) => studentKeywords.contains(r.toLowerCase())));
        
        final audienceMatches = (role == UserRole.teacher && q.audiences.contains(SurveyAudience.teachers)) ||
                                (role == UserRole.student && q.audiences.contains(SurveyAudience.students)) ||
                                (role == UserRole.parent && q.audiences.contains(SurveyAudience.parents)) ||
                                (role == UserRole.other && q.audiences.contains(SurveyAudience.nonTeachingStaff)) ||
                                (q.audiences.contains(SurveyAudience.organMembers));
        
        final isTargeted = q.individualTargetIds.contains(userId) || (userEmail != null && q.individualTargetIds.contains(userEmail));
        final isExcluded = q.excludedTargetIds.contains(userId) || (userEmail != null && q.excludedTargetIds.contains(userEmail));

        return (roleMatches || audienceMatches || isTargeted) && !isExcluded;
      }).toList();
    });
  }

  Stream<Set<String>> getUserAnsweredSurveysStream(String userId) {
    return _db
        .collection('questionnaire_participations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['questionnaireId'] as String).toSet());
  }

  Future<void> submitQuestionnaireResponse(
      QuestionnaireResponse response, String realUserId, {String? institutionId}) async {
    final batch = _db.batch();

    // 1. Save the actual response data to global collection
    batch.set(_db.collection('questionnaire_responses').doc(response.id), response.toMap());

    // 2. Save to institutional sub-collection for monitoring if institutionId is available
    if (institutionId != null) {
      batch.set(
        _db.collection('institutions')
           .doc(institutionId)
           .collection('surveys')
           .doc(response.questionnaireId)
           .collection('responses')
           .doc(response.id),
        response.toMap()
      );
    }

    // 3. Save a participation record with the real user ID for tracking/agenda
    final partId = "${realUserId}_${response.questionnaireId}";
    batch.set(_db.collection('questionnaire_participations').doc(partId), {
      'userId': realUserId,
      'questionnaireId': response.questionnaireId,
      'timestamp': FieldValue.serverTimestamp(),
      'isAnonymous': response.isAnonymous,
    });

    await batch.commit();
  }

  Stream<List<QuestionnaireResponse>> getQuestionnaireResponses(
      String questionnaireId) {
    return _db
        .collection('questionnaire_responses')
        .where('questionnaireId', isEqualTo: questionnaireId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuestionnaireResponse.fromMap(doc.data()))
            .toList());
  }

  Future<void> reopenQuestionnaire(
      String questionnaireId, DateTime newEnd, String reason) async {
    final docRef = _db.collection('questionnaires').doc(questionnaireId);
    final doc = await docRef.get();
    if (doc.exists) {
      final q = Questionnaire.fromMap(doc.data()!);
      final newHistory = List<ReopenLog>.from(q.reopenHistory);
      newHistory.add(ReopenLog(
          startDate: DateTime.now(), endDate: newEnd, reason: reason));

      await docRef.update({
        'endDate': newEnd.toIso8601String(),
        'isActive': true,
        'reopenHistory': newHistory.map((h) => h.toMap()).toList(),
      });
    }
  }

  Future<List<UserModel>> getEligibleUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  Future<void> assignHealthSpecialist(
      String institutionId, String userId) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .update({'healthSpecialistId': userId});
  }

  Stream<List<QuestionnaireResponse>> getSpecialistAccessibleResponses(
      String questionnaireId) {
    return _db
        .collection('questionnaire_responses')
        .where('questionnaireId', isEqualTo: questionnaireId)
        .where('consentToSpecialist', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QuestionnaireResponse.fromMap(doc.data()))
          .toList();
    });
  }

  // --- Gestão Documental Universal (ManagementDocument) ---

  Future<void> saveManagementDocument(ManagementDocument doc) async {
    await _db.collection('management_documents').doc(doc.id).set(doc.toMap());
  }

  Stream<List<ManagementDocument>> getManagementDocuments(
      String ownerId, ManagementDocumentOwnerType type) {
    return _db
        .collection('management_documents')
        .where('ownerId', isEqualTo: ownerId)
        .where('ownerType', isEqualTo: type.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagementDocument.fromMap(doc.data()))
            .toList());
  }

  Future<void> deleteManagementDocument(String docId) async {
    await _db.collection('management_documents').doc(docId).delete();
  }

  Future<void> signDocument(String docId, SignatureEntry signature) async {
    final docRef = _db.collection('management_documents').doc(docId);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      final doc = ManagementDocument.fromMap(docSnap.data()!);
      final updatedSignatures = List<SignatureEntry>.from(doc.signatures);

      // Prevent double signing
      if (updatedSignatures.any((s) => s.userId == signature.userId)) return;

      updatedSignatures.add(signature);

      ManagementDocumentStatus newStatus = doc.status;
      if (updatedSignatures.length >= doc.requiredSignerIds.length) {
        newStatus = ManagementDocumentStatus.completed;
      } else {
        newStatus = ManagementDocumentStatus.signing;
      }

      await docRef.update({
        'signatures': updatedSignatures.map((s) => s.toMap()).toList(),
        'status': newStatus.name,
      });

      // Notify next signer if it exists
      if (newStatus == ManagementDocumentStatus.signing) {
        final nextSignerId = doc.requiredSignerIds[updatedSignatures.length];
        final notification = InternalMessage(
          id: 'sign_${DateTime.now().millisecondsSinceEpoch}_$docId',
          senderId: 'system',
          senderName: 'Gestão de Documentos',
          recipientIds: [nextSignerId],
          subject: 'Documento Aguardando Assinatura: ${doc.title}',
          body:
              'O documento "${doc.title}" foi assinado por ${signature.userName} e aguarda agora a sua assinatura digital.',
          timestamp: DateTime.now(),
        );
        await sendInternalMessage(notification);
      } else if (newStatus == ManagementDocumentStatus.completed) {
        // Notify creator
        final notification = InternalMessage(
          id: 'sign_comp_${DateTime.now().millisecondsSinceEpoch}_$docId',
          senderId: 'system',
          senderName: 'Gestão de Documentos',
          recipientIds: [doc.createdBy],
          subject: 'Documento Totalmente Assinado: ${doc.title}',
          body:
              'O processo de assinatura do documento "${doc.title}" foi concluído com sucesso.',
          timestamp: DateTime.now(),
        );
        await sendInternalMessage(notification);
      }
    }
  }

  Stream<List<ManagementDocument>> getManagementDocumentsForUser(
      String userId) {
    // Returns documents where user is a required signer or owner (if it's a teacher doc)
    // Firestore doesn't support 'OR' queries well across different fields without composite indexes,
    // so we'll fetch based on requiredSignerIds and ownerId separately or use a combined stream.

    // For simplicity in this MVP, we fetch for requiredSignerIds
    return _db
        .collection('management_documents')
        .where('requiredSignerIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManagementDocument.fromMap(doc.data()))
            .toList());
  }

  // --- ERP 360 System ---

  Future<void> saveErpRecord(ErpRecord record) async {
    await _db.collection('erp_records').doc(record.id).set(record.toMap());
  }

  Stream<List<ErpRecord>> getErpRecords(String institutionId,
      {ErpModule? module}) {
    var query = _db
        .collection('erp_records')
        .where('institutionId', isEqualTo: institutionId);
    if (module != null) {
      query = query.where('module', isEqualTo: module.name);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ErpRecord.fromMap(doc.data())).toList());
  }

  Future<void> updateErpRecord(
      String recordId, Map<String, dynamic> data) async {
    await _db.collection('erp_records').doc(recordId).update({
      ...data,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteErpRecord(String recordId) async {
    await _db.collection('erp_records').doc(recordId).delete();
  }

  // --- HR Specialized Methods ---

  Stream<List<HRShift>> getHRShifts(String institutionId) {
    return _db.collection('institutions').doc(institutionId).collection('hr_shifts')
        .snapshots().map((s) => s.docs.map((d) => HRShift.fromMap(d.data())).toList());
  }

  Future<void> saveHRShift(String institutionId, HRShift shift) async {
    await _db.collection('institutions').doc(institutionId).collection('hr_shifts')
        .doc(shift.id).set(shift.toMap());
  }

  Stream<List<HRScheduleEntry>> getHRSchedule(String institutionId, {DateTime? start, DateTime? end}) {
    var query = _db.collection('institutions').doc(institutionId).collection('hr_schedule');
    // Simple way to filter by month/date if needed
    return query.snapshots().map((s) => s.docs.map((d) => HRScheduleEntry.fromMap(d.data())).toList());
  }

  Future<void> saveHRScheduleEntries(String institutionId, List<HRScheduleEntry> entries) async {
    final batch = _db.batch();
    final coll = _db.collection('institutions').doc(institutionId).collection('hr_schedule');
    for (var entry in entries) {
      final id = "${entry.employeeId}_${DateFormat('yyyyMMdd').format(entry.date)}";
      batch.set(coll.doc(id), entry.toMap());
    }
    await batch.commit();
  }

  Stream<List<HRAttendanceRecord>> getHRAttendance(String institutionId, {DateTime? date, String? employeeId, DateTime? month}) {
    Query<Map<String, dynamic>> query = _db.collection('institutions').doc(institutionId).collection('hr_attendance');
    
    if (employeeId != null) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }

    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      query = query.where('dateStr', isEqualTo: dateStr);
    } else if (month != null) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                   .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    
    return query.snapshots().map((s) => s.docs.map((d) => HRAttendanceRecord.fromMap(d.data())).toList());
  }

  Future<void> saveHRAttendance(HRAttendanceRecord record) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
    await _db.collection('institutions').doc(record.institutionId).collection('hr_attendance')
        .doc(record.id).set({
          ...record.toMap(),
          'dateStr': dateStr,
        });
  }

  Stream<List<HRAbsence>> getHRAbsences(String institutionId) {
    return _db.collection('institutions').doc(institutionId).collection('hr_absences')
        .snapshots().map((s) => s.docs.map((d) => HRAbsence.fromMap(d.data())).toList());
  }

  Future<void> saveHRAbsence(HRAbsence absence) async {
    await _db.collection('institutions').doc(absence.institutionId).collection('hr_absences')
        .doc(absence.id).set(absence.toMap());
  }

  Stream<List<HRPerformanceEvaluation>> getHRPerformanceEvaluations(String institutionId, String employeeId) {
    return _db.collection('institutions').doc(institutionId).collection('hr_evaluations')
        .where('employeeId', isEqualTo: employeeId)
        .snapshots().map((s) => s.docs.map((d) => HRPerformanceEvaluation.fromMap(d.data())).toList());
  }

  Future<void> saveHRPerformanceEvaluation(HRPerformanceEvaluation eval) async {
    await _db.collection('institutions').doc(eval.institutionId).collection('hr_evaluations')
        .doc(eval.id).set(eval.toMap());
  }

  Stream<List<HRTraining>> getHRTrainings(String institutionId) {
    return _db.collection('institutions').doc(institutionId).collection('hr_trainings')
        .snapshots().map((s) => s.docs.map((d) => HRTraining.fromMap(d.data())).toList());
  }

  Future<void> saveHRTraining(HRTraining training) async {
    await _db.collection('institutions').doc(training.institutionId).collection('hr_trainings')
        .doc(training.id).set(training.toMap());
  }
  Future<void> saveAttendance(Attendance attendance) async {
    await _db
        .collection('attendance')
        .doc(attendance.id)
        .set(attendance.toMap());
  }

  Future<void> deleteAttendanceBySession(
      String userId, String sessionId) async {
    final query = await _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<Enrollment>> getEnrollmentsForSubjectByUser(
      String subjectId, String userId) {
    return _db
        .collection('enrollments')
        .where('subjectId', isEqualTo: subjectId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Enrollment.fromMap(doc.data()))
            .toList());
  }

  // --- Timetable ---
  Stream<List<TimetableEntry>> getTimetableEntries(String institutionId,
      {String? academicYear}) {
    Query query = _db
        .collection('timetable')
        .where('institutionId', isEqualTo: institutionId);
    if (academicYear != null) {
      query = query.where('academicYear', isEqualTo: academicYear);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(
            (doc) => TimetableEntry.fromMap(doc.data() as Map<String, dynamic>))
        .toList());
  }

  // ─── Surveys ──────────────────────────────────────────────────────────────

  // --- Group Retrieval Helpers ---

  Future<List<UserModel>> getInstitutionDocentes(String institutionId) async {
    final members = await getAllInstitutionMembers(institutionId);
    return members.where((u) => u.role == UserRole.teacher || u.role == UserRole.courseCoordinator).toList();
  }

  Future<List<UserModel>> getInstitutionNaoDocentes(String institutionId) async {
    final members = await getAllInstitutionMembers(institutionId);
    final docenteRoles = [UserRole.teacher, UserRole.courseCoordinator];
    return members.where((u) => !docenteRoles.contains(u.role) && u.role != UserRole.student && u.role != UserRole.parent).toList();
  }

  Future<List<UserModel>> getOrganMembers(String institutionId, String organId) async {
    final doc = await _db.collection('institutional_organs').doc(organId).get();
    if (!doc.exists) return [];
    final organ = InstitutionalOrgan.fromMap(doc.data()!);
    
    // We need to fetch the actual UserModels for these members if they have userId
    final userIds = organ.members.map((m) => m.userId).whereType<String>().toList();
    if (userIds.isEmpty) {
      // Return mock users if no actual user accounts linked yet? 
      // User said "add/remove emails", so we might need user models or just emails.
      // For consistency, let's return a list where name/email match the organ member.
      return organ.members.map((m) => UserModel(
        id: m.userId ?? m.email,
        email: m.email,
        name: m.name,
        role: UserRole.other,
        adConsent: false,
        dataConsent: false,
      )).toList();
    }
    
    final users = <UserModel>[];
    // Fetch in chunks of 30 for whereIn
    for (var i = 0; i < userIds.length; i += 30) {
      final end = (i + 30 < userIds.length) ? i + 30 : userIds.length;
      final chunk = userIds.sublist(i, end);
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      users.addAll(snap.docs.map((d) => UserModel.fromMap(d.data())));
    }
    return users;
  }

  /// Consistently save surveys to the root collection for global agenda/personal area tracking,
  /// AND to the institution specific sub-collection for administrative monitoring.
  Future<void> saveSurvey(Questionnaire survey) async {
    final batch = _db.batch();
    
    // 1. Root collection (for user agenda and targeting)
    batch.set(_db.collection('questionnaires').doc(survey.id), survey.toMap());
    
    // 2. Institution sub-collection (for administrative monitoring)
    batch.set(
      _db.collection('institutions')
         .doc(survey.institutionId)
         .collection('surveys')
         .doc(survey.id), 
      survey.toMap()
    );

    await batch.commit();

    // 3. Notify participants if published as active
    if (survey.status == SurveyStatus.active) {
      _notifyParticipantsOfNewSurvey(survey);
    }
  }

  /// Get a single questionnaire by its ID.
  Future<Questionnaire?> getQuestionnaireById(String id) async {
    final doc = await _db.collection('questionnaires').doc(id).get();
    if (!doc.exists) return null;
    return Questionnaire.fromMap(doc.data()!);
  }

  /// Stream of all surveys for an institution (ordered by creation/startDate)
  Stream<List<Questionnaire>> getSurveysForInstitution(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Questionnaire.fromMap(d.data()))
            .toList());
  }

  /// Stream of surveys created by a specific teacher (across the institution)
  Stream<List<Questionnaire>> getSurveysForTeacher(
      String institutionId, String teacherId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .where('creatorId', isEqualTo: teacherId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Questionnaire.fromMap(d.data()))
            .toList());
  }

  /// Stream of active surveys the current user should answer.
  /// Matches by audience role or individual target IDs.
  Stream<List<Questionnaire>> getActiveSurveysForUser(
      String institutionId, String userId, String role) {
    // Fetch active surveys for this institution and filter client-side
    // (Firestore doesn't support OR queries across different array fields directly)
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Questionnaire.fromMap(d.data()))
            .where((q) {
              if (!q.isCurrentlyActive) return false;
              // Check if user's role is in audiences
              final audienceNames = q.audiences.map((a) => a.name).toList();
              bool roleMatch = false;
              if (role == 'student' && audienceNames.contains('students')) roleMatch = true;
              if (role == 'teacher' && audienceNames.contains('teachers')) roleMatch = true;
              if (role == 'parent' && audienceNames.contains('parents')) roleMatch = true;
              if (role == 'nonTeachingStaff' && audienceNames.contains('nonTeachingStaff')) roleMatch = true;
              // Check individual targeting
              final individualMatch = q.individualTargetIds.contains(userId);
              // Check exclusions
              final isExcluded = q.excludedTargetIds.contains(userId);

              return (roleMatch || individualMatch) && !isExcluded;
            })
            .toList());
  }

  /// Delete a survey (only drafts or closed ones should be deleted)
  Future<void> deleteSurvey(String institutionId, String surveyId) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .delete();
  }

  /// Update the status of a survey (e.g., draft → active, active → closed)
  Future<void> updateSurveyStatus(
      String institutionId, String surveyId, SurveyStatus status) async {
    final batch = _db.batch();
    final statusUpdate = {'status': status.name, 'isActive': status == SurveyStatus.active};

    // 1. Update in institution sub-collection (monitoring dashboard)
    batch.update(
      _db.collection('institutions').doc(institutionId).collection('surveys').doc(surveyId),
      statusUpdate,
    );

    // 2. Update in root collection (user personal area / agenda visibility)
    batch.update(
      _db.collection('questionnaires').doc(surveyId),
      statusUpdate,
    );

    await batch.commit();
  }

  // --- Survey Responses ---

  /// Submit a response from a user.
  Future<void> submitSurveyResponse(
      String institutionId, QuestionnaireResponse response) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(response.questionnaireId)
        .collection('responses')
        .doc(response.id)
        .set(response.toMap());
  }

  /// Stream of all responses for a given survey.
  Stream<List<QuestionnaireResponse>> getSurveyResponses(
      String institutionId, String surveyId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .collection('responses')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => QuestionnaireResponse.fromMap(d.data()))
            .toList());
  }

  /// Check whether a specific user has already responded to a survey.
  Future<bool> hasUserRespondedToSurvey(
      String institutionId, String surveyId, String userId) async {
    final snap = await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .collection('responses')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // --- Survey Analysis & Summary ---

  /// Save or update the AI-generated summary for a survey.
  Future<void> saveSurveySummary(
      String institutionId, SurveyResponseSummary summary) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(summary.questionnaireId)
        .collection('analysis')
        .doc('summary')
        .set(summary.toMap());
  }

  /// Stream of the analysis summary document for a survey.
  Stream<SurveyResponseSummary?> getSurveySummary(
      String institutionId, String surveyId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .collection('analysis')
        .doc('summary')
        .snapshots()
        .map((snap) =>
            snap.exists ? SurveyResponseSummary.fromMap(snap.data()!) : null);
  }

  /// Lock the survey report to prevent further editing.
  Future<void> lockSurveyReport(
      String institutionId, String surveyId) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .collection('analysis')
        .doc('summary')
        .update({
      'isLocked': true,
      'lockedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Update the human notes on a survey summary.
  Future<void> updateSurveyHumanNotes(
      String institutionId, String surveyId, String notes) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .collection('analysis')
        .doc('summary')
        .update({'humanNotes': notes});
  }

  Future<void> updateSurveyVisibility(
      String institutionId,
      String surveyId,
      SurveyVisibility visibility) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('surveys')
        .doc(surveyId)
        .update({'visibility': visibility.name});
  }


  // --- Course Reports ---

  Future<void> saveCourseReport(CourseReport report) async {
    await _db
        .collection('course_reports')
        .doc(report.id)
        .set(report.toMap());
  }

  Stream<List<CourseReport>> getCourseReportsStream(String courseId) {
    return _db
        .collection('course_reports')
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CourseReport.fromMap(d.data()))
            .toList()
          ..sort((a, b) => b.academicYear.compareTo(a.academicYear)));
  }

  // --- Assignments (Trabalhos / Submissões) ---

  Future<void> createAssignment(String institutionId, Assignment assignment) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('assignments')
        .doc(assignment.id)
        .set(assignment.toMap());
  }

  Stream<List<Assignment>> getAssignmentsForSubject(String institutionId, String subjectId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('assignments')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Assignment.fromMap(doc.data())).toList());
  }

  Future<void> updateAssignment(String institutionId, Assignment assignment) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('assignments')
        .doc(assignment.id)
        .update(assignment.toMap());
  }

  Future<void> deleteAssignment(String institutionId, String assignmentId) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('assignments')
        .doc(assignmentId)
        .delete();
  }

  Future<void> submitAssignmentWork(String institutionId, String assignmentId, AssignmentSubmission submission) async {
    final ref = _db.collection('institutions').doc(institutionId).collection('assignments').doc(assignmentId);
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception("Assignment does not exist!");
      
      final assignment = Assignment.fromMap(snapshot.data()!);
      final submissionsList = List<AssignmentSubmission>.from(assignment.submissions);
      
      final index = submissionsList.indexWhere((s) => s.id == submission.id);
      if (index != -1) {
        submissionsList[index] = submission;
      } else {
        submissionsList.add(submission);
      }
      
      transaction.update(ref, {'submissions': submissionsList.map((x) => x.toMap()).toList()});
    });
  }

  // --- Monitoring & Coordinator Actions ---

  Stream<SchoolCalendar?> getSchoolCalendarStream(
      String institutionId, String academicYear) {
    return _db
        .collection('school_calendars')
        .where('institutionId', isEqualTo: institutionId)
        .where('academicYear', isEqualTo: academicYear)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SchoolCalendar.fromMap(snapshot.docs.first.data());
    });
  }

  Future<void> duplicateAcademicYearSettings(String institutionId,
      String sourceYear, String targetYear, String userId) async {
    final calendarSnap = await _db
        .collection('school_calendars')
        .where('institutionId', isEqualTo: institutionId)
        .where('academicYear', isEqualTo: sourceYear)
        .get();

    if (calendarSnap.docs.isNotEmpty) {
      final sourceCalendar = SchoolCalendar.fromMap(calendarSnap.docs.first.data());
      final newCalendar = SchoolCalendar(
        id: const Uuid().v4(),
        institutionId: institutionId,
        academicYear: targetYear,
        terms: sourceCalendar.terms,
        holidays: sourceCalendar.holidays,
        vacations: sourceCalendar.vacations,
        deadlines: sourceCalendar.deadlines,
      );
      await saveSchoolCalendar(newCalendar);
    }
  }

  Future<String> getCurrentAcademicYear(String institutionId) async {
    try {
      final snap = await _db
          .collection('school_calendars')
          .where('institutionId', isEqualTo: institutionId)
          .orderBy('academicYear', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data()['academicYear'] ?? '2024/2025';
      }
    } catch (e) {
      debugPrint('Error fetching academic year: $e');
    }
    return '2024/2025'; // Fallback
  }

  Future<void> sendInstitutionalNotification({
    required List<String> recipientIds,
    required String title,
    required String body,
    required String senderName,
    String category = 'academic_alert',
    String? relatedEntityId,
  }) async {
    final msgId = const Uuid().v4();
    final message = InternalMessage(
      id: msgId,
      senderId: 'system',
      senderName: senderName,
      recipientIds: recipientIds,
      subject: title,
      body: body,
      timestamp: DateTime.now(),
      category: category,
      relatedEntityId: relatedEntityId,
    );
    await _db.collection('messages').doc(msgId).set(message.toMap());
  }

  Future<void> sendCoordinatorWarning({
    required String teacherId,
    required String subjectId,
    required String subjectName,
    required String message,
    required String coordinatorName,
  }) async {
    final msgId = const Uuid().v4();
    final internalMsg = InternalMessage(
      id: msgId,
      senderId: 'SYSTEM_COORDINATOR',
      senderName: 'Coordenador: $coordinatorName',
      recipientIds: [teacherId],
      subject: 'Aviso Académico: $subjectName',
      body: message,
      timestamp: DateTime.now(),
      category: 'academic_alert',
    );
    await sendInternalMessage(internalMsg);
  }

  // --- Fixed Questionnaire Visibility ---

  Stream<List<Questionnaire>> getPendingSurveysForUser(
      String userId, String? userEmail, UserRole role, String institutionId) {
    return _db
        .collection('questionnaires')
        .where('institutionId', isEqualTo: institutionId)
        .where('status', isEqualTo: SurveyStatus.active.name)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Questionnaire.fromMap(doc.data()))
          .where((q) {
        // Broad date check (today included)
        if (now.isAfter(q.endDate.add(const Duration(days: 1))) || 
            now.isBefore(q.startDate.subtract(const Duration(hours: 1)))) return false;

        final teacherKeywords = ['teachers', 'teacher', 'docente', 'pessoal docente', 'professor', 'professores'];
        final studentKeywords = ['students', 'student', 'aluno', 'alunos'];

        final roleMatches = q.targetRoles.contains('all') ||
            q.targetRoles.contains(role.name) ||
            (role == UserRole.teacher && q.targetRoles.any((r) => teacherKeywords.contains(r.toLowerCase()))) ||
            (role == UserRole.student && q.targetRoles.any((r) => studentKeywords.contains(r.toLowerCase())));
        
        final audienceMatches = (role == UserRole.teacher && q.audiences.contains(SurveyAudience.teachers)) ||
                                (role == UserRole.student && q.audiences.contains(SurveyAudience.students)) ||
                                (role == UserRole.parent && q.audiences.contains(SurveyAudience.parents)) ||
                                (role == UserRole.other && q.audiences.contains(SurveyAudience.nonTeachingStaff)) ||
                                (q.audiences.contains(SurveyAudience.organMembers)); // We'll assume if it's organMembers, we check individualTargetIds or member list
        
        final isTargeted = q.individualTargetIds.contains(userId) || (userEmail != null && q.individualTargetIds.contains(userEmail));
        final isExcluded = q.excludedTargetIds.contains(userId) || (userEmail != null && q.excludedTargetIds.contains(userEmail));

        return (roleMatches || audienceMatches || isTargeted) && !isExcluded;
      }).toList();
    });
  }

  // --- Unified Agenda System ---

  Stream<List<AgendaItem>> getUnifiedAgendaStream(
      String userId, String? userEmail, UserRole role, String institutionId) {
    // 0. Responses helper (to mark surveys as completed)
    final responsesStream = _db
        .collection('questionnaire_participations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['questionnaireId'] as String).toSet());

    // 1. Assignments
    final assignmentsStream = _db
        .collection('institutions')
        .doc(institutionId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Assignment.fromMap(doc.data())).toList();
          return list.where((a) {
            if (role == UserRole.institution) return true;
            // For now, show all for the institution, but filter by relevance if possible
            return true; 
          }).map((a) => AgendaItem(
            title: a.title,
            description: a.description,
            type: AgendaItemType.assignment,
            startDate: a.createdAt,
            dueDate: a.dueDate,
            status: _calculateAssignmentStatus(a, userId, role),
            relatedId: a.id,
          )).toList();
        });

    // 2. Questionnaires (Surveys)
    final questionnairesStream = Rx.combineLatest2(
      getPendingSurveysForUser(userId, userEmail, role, institutionId),
      responsesStream,
      (List<Questionnaire> surveys, Set<String> answeredIds) {
        return surveys.map((q) => AgendaItem(
          title: q.title,
          description: q.description,
          type: AgendaItemType.questionnaire,
          startDate: q.startDate,
          dueDate: q.endDate,
          status: answeredIds.contains(q.id) ? AgendaItemStatus.completed : AgendaItemStatus.pending,
          relatedId: q.id,
        )).toList();
      },
    );

    // 3. Calendar Deadlines
    final calendarStream = getSchoolCalendarStream(institutionId, '2024/2025')
        .map((cal) {
          if (cal == null) return <AgendaItem>[];
          final d = cal.deadlines;
          final items = <AgendaItem>[];
          
          if (role == UserRole.teacher || role == UserRole.institution) {
            if (d?.programSubmissionDeadline != null) {
              items.add(AgendaItem(
                title: 'Submissão de Programas',
                type: AgendaItemType.deadline,
                startDate: d!.programSubmissionDeadline!.subtract(const Duration(days: 7)),
                dueDate: d.programSubmissionDeadline!,
                relatedId: cal.id,
              ));
            }
            if (d?.gradingDeadline != null) {
              items.add(AgendaItem(
                title: 'Lançamento de Notas',
                type: AgendaItemType.deadline,
                startDate: d!.gradingDeadline!.subtract(const Duration(days: 7)),
                dueDate: d.gradingDeadline!,
                relatedId: cal.id,
              ));
            }
          }
          return items;
        });

    // 4. Institutional Activities
    final activitiesStream = _db
        .collection('activities')
        .where('institutionId', isEqualTo: institutionId)
        .snapshots()
        .map((snapshot) {
          final all = snapshot.docs
              .map((doc) => InstitutionalActivity.fromMap(
                  doc.data() as Map<String, dynamic>))
              .toList();
          return all.where((act) {
            final isParticipant = act.participants.any((p) => p.email.toLowerCase() == (userEmail?.toLowerCase() ?? '') || p.id == userId);
            final isResponsible = act.responsibleUserId == userId;
            final isDirection = role == UserRole.institution;
            return isParticipant || isResponsible || isDirection;
          }).map((act) => AgendaItem(
            title: act.title,
            description: act.description,
            type: AgendaItemType.activity,
            startDate: act.startDate,
            dueDate: act.endDate,
            status: act.status == 'completed' ? AgendaItemStatus.completed : AgendaItemStatus.pending,
            relatedId: act.id,
          )).toList();
        });

    // Combine all
    return Rx.combineLatest4(
      assignmentsStream,
      questionnairesStream,
      calendarStream,
      activitiesStream,
      (List<AgendaItem> a, List<AgendaItem> q, List<AgendaItem> c, List<AgendaItem> act) => 
          [...a, ...q, ...c, ...act]..sort((i1, i2) => i1.dueDate.compareTo(i2.dueDate)),
    );
  }

  AgendaItemStatus _calculateAssignmentStatus(Assignment a, String userId, UserRole role) {
    if (role == UserRole.student) {
      final sub = a.submissions.where((s) => s.studentId == userId).firstOrNull;
      if (sub != null) return AgendaItemStatus.completed;
    }
    if (DateTime.now().isAfter(a.dueDate)) return AgendaItemStatus.overdue;
    return AgendaItemStatus.pending;
  }

  Future<void> updateDelegatedRole(String institutionId, String userId, String module, bool add) async {
    final docRef = _db.collection('institutions').doc(institutionId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final institution = InstitutionModel.fromMap(doc.data()!);
    final roles = Map<String, List<String>>.from(institution.delegatedRoles);
    final list = List<String>.from(roles[module] ?? []);

    if (add) {
      if (!list.contains(userId)) list.add(userId);
    } else {
      list.remove(userId);
    }

    roles[module] = list;
    await docRef.update({'delegatedRoles': roles});
  }
  // --- Finance 360 ---
  Stream<List<FinanceTransaction>> getFinanceTransactions(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('finance_transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinanceTransaction.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> saveFinanceTransaction(FinanceTransaction transaction) async {
    final batch = _db.batch();
    final docRef = _db
        .collection('institutions')
        .doc(transaction.institutionId)
        .collection('finance_transactions')
        .doc();
    
    batch.set(docRef, transaction.toMap());
    
    // Update budget if applicable
    final budgets = await _db
        .collection('institutions')
        .doc(transaction.institutionId)
        .collection('finance_budgets')
        .where('year', isEqualTo: transaction.date.year)
        .where('category', isEqualTo: transaction.category.name)
        .get();
        
    for (var doc in budgets.docs) {
      batch.update(doc.reference, {
        'spentAmount': FieldValue.increment(transaction.type == TransactionType.expense ? transaction.amount : -transaction.amount)
      });
    }

    await batch.commit();
  }

  Stream<List<FinanceInvoice>> getFinanceInvoices(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('finance_invoices')
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinanceInvoice.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> saveFinanceInvoice(FinanceInvoice invoice) async {
    await _db
        .collection('institutions')
        .doc(invoice.institutionId)
        .collection('finance_invoices')
        .doc(invoice.id.isEmpty ? null : invoice.id)
        .set(invoice.toMap(), SetOptions(merge: true));
  }

  Stream<List<FinanceBudget>> getFinanceBudgets(String institutionId, int year) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('finance_budgets')
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinanceBudget.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> saveFinanceBudget(FinanceBudget budget) async {
    await _db
        .collection('institutions')
        .doc(budget.institutionId)
        .collection('finance_budgets')
        .doc(budget.id.isEmpty ? null : budget.id)
        .set(budget.toMap(), SetOptions(merge: true));
  }
}
