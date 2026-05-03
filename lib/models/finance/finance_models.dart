import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense, transfer }
enum TransactionStatus { pending, completed, cancelled, disputed }
enum TransactionCategory { 
  tuition, 
  salary, 
  maintenance, 
  supplies, 
  utilities, 
  events, 
  donations, 
  other 
}

class FinanceTransaction {
  final String id;
  final String institutionId;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final TransactionStatus status;
  final TransactionCategory category;
  final String? relatedEntityId; // User ID, Supplier ID, etc.
  final String? invoiceId;
  final String? paymentMethodId;
  final List<String> attachmentUrls;

  FinanceTransaction({
    required this.id,
    required this.institutionId,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    required this.category,
    this.relatedEntityId,
    this.invoiceId,
    this.paymentMethodId,
    this.attachmentUrls = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'institutionId': institutionId,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'status': status.name,
      'category': category.name,
      'relatedEntityId': relatedEntityId,
      'invoiceId': invoiceId,
      'paymentMethodId': paymentMethodId,
      'attachmentUrls': attachmentUrls,
    };
  }

  factory FinanceTransaction.fromMap(String id, Map<String, dynamic> map) {
    return FinanceTransaction(
      id: id,
      institutionId: map['institutionId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      type: TransactionType.values.firstWhere((e) => e.name == map['type'], orElse: () => TransactionType.income),
      status: TransactionStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => TransactionStatus.completed),
      category: TransactionCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => TransactionCategory.other),
      relatedEntityId: map['relatedEntityId'],
      invoiceId: map['invoiceId'],
      paymentMethodId: map['paymentMethodId'],
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []),
    );
  }
}

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }

class FinanceInvoice {
  final String id;
  final String institutionId;
  final String invoiceNumber;
  final String customerName;
  final String? customerId;
  final String? customerTaxId;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final double totalAmount;
  final double taxAmount;
  final InvoiceStatus status;
  final String? note;
  final String? pdfUrl;

  FinanceInvoice({
    required this.id,
    required this.institutionId,
    required this.invoiceNumber,
    required this.customerName,
    this.customerId,
    this.customerTaxId,
    required this.issueDate,
    required this.dueDate,
    required this.items,
    required this.totalAmount,
    required this.taxAmount,
    required this.status,
    this.note,
    this.pdfUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'institutionId': institutionId,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerId': customerId,
      'customerTaxId': customerTaxId,
      'issueDate': Timestamp.fromDate(issueDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'status': status.name,
      'note': note,
      'pdfUrl': pdfUrl,
    };
  }

  factory FinanceInvoice.fromMap(String id, Map<String, dynamic> map) {
    return FinanceInvoice(
      id: id,
      institutionId: map['institutionId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      customerName: map['customerName'] ?? '',
      customerId: map['customerId'],
      customerTaxId: map['customerTaxId'],
      issueDate: (map['issueDate'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      items: (map['items'] as List? ?? []).map((e) => InvoiceItem.fromMap(e)).toList(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0.0).toDouble(),
      status: InvoiceStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => InvoiceStatus.sent),
      note: map['note'],
      pdfUrl: map['pdfUrl'],
    );
  }
}

class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxRate;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.23, // Default PT VAT
  });

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
    description: map['description'] ?? '',
    quantity: (map['quantity'] ?? 1.0).toDouble(),
    unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
    taxRate: (map['taxRate'] ?? 0.23).toDouble(),
  );
}

class FinanceBudget {
  final String id;
  final String institutionId;
  final String name;
  final int year;
  final TransactionCategory category;
  final double targetAmount;
  final double spentAmount;

  FinanceBudget({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.year,
    required this.category,
    required this.targetAmount,
    this.spentAmount = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'name': name,
    'year': year,
    'category': category.name,
    'targetAmount': targetAmount,
    'spentAmount': spentAmount,
  };

  factory FinanceBudget.fromMap(String id, Map<String, dynamic> map) => FinanceBudget(
    id: id,
    institutionId: map['institutionId'] ?? '',
    name: map['name'] ?? '',
    year: map['year'] ?? DateTime.now().year,
    category: TransactionCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => TransactionCategory.other),
    targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
    spentAmount: (map['spentAmount'] ?? 0.0).toDouble(),
  );
}
