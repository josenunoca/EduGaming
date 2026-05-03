import 'package:cloud_firestore/cloud_firestore.dart';

class StockBatch {
  final String id;
  final String institutionId;
  final String itemId;
  final String size;
  final String color;
  final String warehouseId;
  final double originalQuantity;
  final double remainingQuantity;
  final double unitCost;
  final DateTime createdAt;
  final String entryId;

  StockBatch({
    required this.id,
    required this.institutionId,
    required this.itemId,
    required this.size,
    required this.color,
    required this.warehouseId,
    required this.originalQuantity,
    required this.remainingQuantity,
    required this.unitCost,
    required this.createdAt,
    required this.entryId,
  });

  Map<String, dynamic> toMap() => {
        'institutionId': institutionId,
        'itemId': itemId,
        'size': size,
        'color': color,
        'warehouseId': warehouseId,
        'originalQuantity': originalQuantity,
        'remainingQuantity': remainingQuantity,
        'unitCost': unitCost,
        'createdAt': Timestamp.fromDate(createdAt),
        'entryId': entryId,
      };

  factory StockBatch.fromMap(String id, Map<String, dynamic> map) => StockBatch(
        id: id,
        institutionId: map['institutionId'] ?? '',
        itemId: map['itemId'] ?? '',
        size: map['size'] ?? '',
        color: map['color'] ?? 'N/A',
        warehouseId: map['warehouseId'] ?? '',
        originalQuantity: (map['originalQuantity'] ?? 0.0).toDouble(),
        remainingQuantity: (map['remainingQuantity'] ?? 0.0).toDouble(),
        unitCost: (map['unitCost'] ?? 0.0).toDouble(),
        createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
        entryId: map['entryId'] ?? '',
      );
}
