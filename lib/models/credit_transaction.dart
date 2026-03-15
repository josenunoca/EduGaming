
enum TransactionType { usage, recharge, limitAdjustment }

class CreditTransaction {
  final String id;
  final String userId;
  final String institutionId;
  final int amount;
  final String description;
  final DateTime timestamp;
  final TransactionType type;

  CreditTransaction({
    required this.id,
    required this.userId,
    required this.institutionId,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'institutionId': institutionId,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      amount: map['amount'] ?? 0,
      description: map['description'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => TransactionType.usage,
      ),
    );
  }
}
