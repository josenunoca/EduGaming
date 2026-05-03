import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance/financial_report_model.dart';
import '../models/finance/finance_models.dart';
import 'firebase_service.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseService _firebaseService;

  FinanceService(this._firebaseService);

  Future<void> saveReport(FinancialReport report) async {
    final ref = _db.collection('institutions').doc(report.institutionId).collection('financial_reports').doc(report.id);
    await ref.set(report.toMap());
  }

  Stream<List<FinancialReport>> getReports(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('financial_reports')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => FinancialReport.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> deleteReport(String institutionId, String reportId) async {
    await _db.collection('institutions').doc(institutionId).collection('financial_reports').doc(reportId).delete();
  }

  Future<double> getTotalIncomeForPeriod(String institutionId, DateTime start, DateTime end) async {
    // Simplified query to avoid index issues. Get all and filter locally.
    final snap = await _db.collection('institutions').doc(institutionId).collection('finance_transactions')
        .get();
    
    double total = 0.0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final type = data['type'];
      final date = (data['date'] as Timestamp?)?.toDate();
      
      if (type == TransactionType.income.name && 
          date != null && 
          date.isAfter(start.subtract(const Duration(seconds: 1))) && 
          date.isBefore(end.add(const Duration(seconds: 1)))) {
        total += (data['amount'] ?? 0.0).toDouble();
      }
    }
    return total;
  }

  Future<double> getTotalExpenseForPeriod(String institutionId, DateTime start, DateTime end) async {
    // Simplified query to avoid index issues. Get all and filter locally.
    final snap = await _db.collection('institutions').doc(institutionId).collection('finance_transactions')
        .get();
    
    double total = 0.0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final type = data['type'];
      final date = (data['date'] as Timestamp?)?.toDate();
      
      if (type == TransactionType.expense.name && 
          date != null && 
          date.isAfter(start.subtract(const Duration(seconds: 1))) && 
          date.isBefore(end.add(const Duration(seconds: 1)))) {
        total += (data['amount'] ?? 0.0).toDouble();
      }
    }
    return total;
  }

  Future<int> generateMonthlyTuitionInvoices(String institutionId, double amount, String period) async {
    // Mock implementation for the UI button in finance_management_screen.dart
    await Future.delayed(const Duration(seconds: 2));
    return 42; // Example count
  }
}
