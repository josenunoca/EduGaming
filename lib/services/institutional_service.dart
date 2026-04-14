import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/institution_organ_model.dart';

class InstitutionalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Organ Management
  Future<List<InstitutionOrgan>> getOrgans() async {
    final snapshot = await _db.collection('organs').orderBy('name').get();
    return snapshot.docs.map((doc) => InstitutionOrgan.fromFirestore(doc)).toList();
  }

  Future<String> createOrgan(InstitutionOrgan organ) async {
    final docRef = await _db.collection('organs').add(organ.toMap());
    return docRef.id;
  }

  // Meeting Management
  Future<List<Meeting>> getMeetings(String organId) async {
    final snapshot = await _db
        .collection('meetings')
        .where('organId', isEqualTo: organId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
  }

  Future<String> createMeeting(Meeting meeting) async {
    final docRef = await _db.collection('meetings').add(meeting.toMap());
    return docRef.id;
  }

  Future<void> updateMeeting(String meetingId, Map<String, dynamic> data) async {
    await _db.collection('meetings').doc(meetingId).update(data);
  }

  Future<String> uploadMeetingDocument(String meetingId, Uint8List bytes, String fileName) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('meetings/$meetingId/documents/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    
    final uploadTask = await storageRef.putData(bytes);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<List<Participant>> getOrganMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final snapshot = await _db.collection('users').where(FieldPath.documentId, whereIn: memberIds).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Participant(
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        status: 'invited',
      );
    }).toList();
  }

  Future<void> updateParticipantStatus(String meetingId, String email, String status) async {
    final meetingDoc = await _db.collection('meetings').doc(meetingId).get();
    if (!meetingDoc.exists) return;

    final meeting = Meeting.fromFirestore(meetingDoc);
    final updatedParticipants = meeting.participants.map((p) {
      if (p.email == email) {
        return Participant(
          name: p.name,
          email: p.email,
          status: status,
          isGuest: p.isGuest,
        );
      }
      return p;
    }).toList();

    await _db.collection('meetings').doc(meetingId).update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> updateParticipantEmailStatus(String meetingId, String email, {bool isRead = false}) async {
    final meetingDoc = await _db.collection('meetings').doc(meetingId).get();
    if (!meetingDoc.exists) return;

    final meeting = Meeting.fromFirestore(meetingDoc);
    final now = DateTime.now();
    final updatedParticipants = meeting.participants.map((p) {
      if (p.email == email) {
        return p.copyWith(
          deliveredAt: p.deliveredAt ?? now,
          readAt: isRead ? (p.readAt ?? now) : p.readAt,
        );
      }
      return p;
    }).toList();

    await _db.collection('meetings').doc(meetingId).update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> markScheduledMeetingAsDelivered(String meetingId) async {
    final meetingDoc = await _db.collection('meetings').doc(meetingId).get();
    if (!meetingDoc.exists) return;

    final meeting = Meeting.fromFirestore(meetingDoc);
    final now = DateTime.now();
    final updatedParticipants = meeting.participants.map((p) {
      return p.copyWith(deliveredAt: now);
    }).toList();

    await _db.collection('meetings').doc(meetingId).update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });
  }

  Stream<List<Meeting>> getMeetingsStream(String organId) {
    return _db
        .collection('meetings')
        .where('organId', isEqualTo: organId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList());
  }

  Stream<List<InstitutionOrgan>> getOrgansStream() {
    return _db
        .collection('organs')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InstitutionOrgan.fromFirestore(doc)).toList());
  }

  bool isLeaderForOrgan(InstitutionOrgan organ, String? userEmail) {
    if (userEmail == null) return false;
    return organ.presidentEmail == userEmail || organ.vicePresidentEmail == userEmail;
  }

  Stream<List<Meeting>> getActiveMeetingsStream() {
    return _db
        .collection('meetings')
        .where('status', whereIn: ['scheduled', 'ongoing'])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList());
  }

  Future<int> getMeetingsForOrganCount(String organId) async {
    final snapshot = await _db
        .collection('meetings')
        .where('organId', isEqualTo: organId)
        .limit(1)
        .get();
    return snapshot.docs.length;
  }

  Future<void> deleteOrgan(String organId) async {
    await _db.collection('organs').doc(organId).delete();
  }

  Future<void> updateOrganActiveStatus(String organId, bool isActive) async {
    await _db.collection('organs').doc(organId).update({'isActive': isActive});
  }
}
