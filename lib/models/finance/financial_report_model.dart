import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialReport {
  final String id;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final double revenueActivities;
  final double revenueInventory;
  final double costActivities;
  final double costInventory;
  final double otherExpenses;
  final double otherIncome;
  final double inventoryAdjustments; // Positive = Surplus, Negative = Loss
  final String notes;
  final DateTime createdAt;
  final String createdById;

  FinancialReport({
    required this.id,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    this.revenueActivities = 0.0,
    this.revenueInventory = 0.0,
    this.costActivities = 0.0,
    this.costInventory = 0.0,
    this.otherExpenses = 0.0,
    this.otherIncome = 0.0,
    this.inventoryAdjustments = 0.0,
    this.notes = '',
    required this.createdAt,
    required this.createdById,
  });

  double get totalRevenue => revenueActivities + revenueInventory + otherIncome + (inventoryAdjustments > 0 ? inventoryAdjustments : 0);
  double get totalCost => costActivities + costInventory + otherExpenses + (inventoryAdjustments < 0 ? inventoryAdjustments.abs() : 0);
  double get netProfit => totalRevenue - totalCost;

  Map<String, dynamic> toMap() => {
        'institutionId': institutionId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'revenueActivities': revenueActivities,
        'revenueInventory': revenueInventory,
        'costActivities': costActivities,
        'costInventory': costInventory,
        'otherExpenses': otherExpenses,
        'otherIncome': otherIncome,
        'inventoryAdjustments': inventoryAdjustments,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdById': createdById,
      };

  factory FinancialReport.fromMap(String id, Map<String, dynamic> map) => FinancialReport(
        id: id,
        institutionId: map['institutionId'] ?? '',
        startDate: (map['startDate'] as Timestamp).toDate(),
        endDate: (map['endDate'] as Timestamp).toDate(),
        revenueActivities: (map['revenueActivities'] ?? 0.0).toDouble(),
        revenueInventory: (map['revenueInventory'] ?? 0.0).toDouble(),
        costActivities: (map['costActivities'] ?? 0.0).toDouble(),
        costInventory: (map['costInventory'] ?? 0.0).toDouble(),
        otherExpenses: (map['otherExpenses'] ?? 0.0).toDouble(),
        otherIncome: (map['otherIncome'] ?? 0.0).toDouble(),
        inventoryAdjustments: (map['inventoryAdjustments'] ?? 0.0).toDouble(),
        notes: map['notes'] ?? '',
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        createdById: map['createdById'] ?? '',
      );
}
