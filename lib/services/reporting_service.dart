import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject_model.dart';
import '../models/questionnaire_model.dart';
import '../models/survey_response_summary_model.dart';
import 'dart:async';

class ReportingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculates attendance metrics for a specific course and academic year.
  Future<Map<String, dynamic>> getCourseAttendanceMetrics(
      String courseId, String academicYear) async {
    // 1. Get all subjects for this course
    final subjectsSnapshot = await _db
        .collection('subjects')
        .where('courseId', isEqualTo: courseId)
        .where('academicYear', isEqualTo: academicYear)
        .get();

    final subjects = subjectsSnapshot.docs.map((doc) => Subject.fromMap(doc.data())).toList();

    int totalExpectedAttendances = 0;
    int actualAttendances = 0;
    int totalFinalizedSessions = 0;
    int totalPlannedSessions = 0;
    Set<String> uniqueStudents = {};
    final List<Map<String, dynamic>> subjectMetrics = [];

    for (var subject in subjects) {
      final finalizedSessions = subject.sessions.where((s) => s.isFinalized).toList();
      totalFinalizedSessions += finalizedSessions.length;
      totalPlannedSessions += subject.sessions.length;

      // Get accepted enrollments for this subject
      final enrollmentSnapshot = await _db
          .collection('enrollments')
          .where('subjectId', isEqualTo: subject.id)
          .where('status', isEqualTo: 'accepted')
          .get();
      
      final studentCount = enrollmentSnapshot.docs.length;
      for (var doc in enrollmentSnapshot.docs) {
        uniqueStudents.add(doc.data()['userId'] ?? '');
      }
      
      totalExpectedAttendances += studentCount * finalizedSessions.length;

      int subjectActualAttendances = 0;
      // Get all attendance records for finalized sessions of this subject
      for (var session in finalizedSessions) {
        final attendanceSnapshot = await _db
            .collection('attendances')
            .where('subjectId', isEqualTo: subject.id)
            .where('sessionId', isEqualTo: session.id)
            .get();
        subjectActualAttendances += attendanceSnapshot.docs.length;
      }
      actualAttendances += subjectActualAttendances;

      subjectMetrics.add({
        'subjectName': subject.name,
        'attendanceRatio': studentCount > 0 && finalizedSessions.isNotEmpty 
            ? (subjectActualAttendances / (studentCount * finalizedSessions.length)) 
            : 0.0,
        'sessionsDelivered': finalizedSessions.length,
        'sessionsPlanned': subject.sessions.length,
      });
    }

    double attendanceRatio = totalExpectedAttendances > 0 
        ? (actualAttendances / totalExpectedAttendances)
        : 0.0;
    
    double syllabusRatio = totalPlannedSessions > 0 
        ? (totalFinalizedSessions / totalPlannedSessions)
        : 0.0;

    // Get unique teacher info
    final Map<String, Map<String, String>> teacherInfo = {};
    for (var subject in subjects) {
      if (subject.teacherId != null && !teacherInfo.containsKey(subject.teacherId)) {
        final teacherDoc = await _db.collection('users').doc(subject.teacherId).get();
        if (teacherDoc.exists) {
          teacherInfo[subject.teacherId!] = {
            'name': teacherDoc.data()?['name'] ?? 'Docente',
            'email': teacherDoc.data()?['email'] ?? '',
          };
        }
      }
    }

    return {
      'attendancePercentage': attendanceRatio * 100,
      'syllabusCoveragePercentage': syllabusRatio * 100,
      'totalSessionsFinalized': totalFinalizedSessions,
      'totalSessionsPlanned': totalPlannedSessions,
      'totalAcceptedStudents': uniqueStudents.length,
      'subjectMetrics': subjectMetrics,
      'teachers': teacherInfo,
    };
  }

  /// Aggregates survey results into a SurveyResponseSummary.
  Future<SurveyResponseSummary> aggregateQuestionnaireResults(String questionnaireId) async {
    final responsesSnapshot = await _db
        .collection('questionnaire_responses')
        .where('questionnaireId', isEqualTo: questionnaireId)
        .get();

    final questionnaireDoc = await _db.collection('questionnaires').doc(questionnaireId).get();
    if (!questionnaireDoc.exists) throw Exception('Questionnaire not found');
    final questionnaire = Questionnaire.fromMap(questionnaireDoc.data()!);

    final responses = responsesSnapshot.docs
        .map((doc) => QuestionnaireResponse.fromMap(doc.data()))
        .toList();

    Map<String, Map<String, int>> quantitativeData = {};
    for (var q in questionnaire.questions) {
      quantitativeData[q.id] = {};
    }

    for (var resp in responses) {
      resp.answers.forEach((qId, answer) {
        if (quantitativeData.containsKey(qId)) {
          String answerStr = answer.toString();
          quantitativeData[qId]![answerStr] = (quantitativeData[qId]![answerStr] ?? 0) + 1;
        }
      });
    }

    return SurveyResponseSummary(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      questionnaireId: questionnaireId,
      generatedAt: DateTime.now(),
      quantitativeData: quantitativeData,
      totalResponses: responses.length,
    );
  }

  /// Aggregates all questionnaires marked for reporting for a specific course.
  Future<Map<String, dynamic>> getCourseSurveysAggregates(String courseId) async {
    final questionnairesSnapshot = await _db
        .collection('questionnaires')
        .where('courseId', isEqualTo: courseId)
        .where('includeInReports', isEqualTo: true)
        .get();

    final aggregates = <Map<String, dynamic>>[];
    for (var doc in questionnairesSnapshot.docs) {
      final summary = await aggregateQuestionnaireResults(doc.id);
      aggregates.add({
        'title': doc.data()['title'] ?? 'Inquérito',
        'summary': summary.toMap(),
      });
    }

    return {'surveys': aggregates};
  }

  /// Gets a full snapshot of metrics and surveys for a course report.
  Future<Map<String, dynamic>> getCourseReportSnapshot(String courseId, String academicYear) async {
    final metrics = await getCourseAttendanceMetrics(courseId, academicYear);
    final surveys = await getCourseSurveysAggregates(courseId);

    return {
      ...metrics,
      ...surveys,
    };
  }
}
