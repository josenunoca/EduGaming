import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, paid, preparing, ready, delivered, cancelled, invoiced }
enum ProcurementCategory { uniform, equipment, supplies, other }

class ProcurementVariant {
  final String size;
  final String color;

  ProcurementVariant({required this.size, required this.color});
}

class ProcurementFamily {
  final String id;
  final String institutionId;
  final String name;

  ProcurementFamily({required this.id, required this.institutionId, required this.name});

  Map<String, dynamic> toMap() => {'institutionId': institutionId, 'name': name};
  factory ProcurementFamily.fromMap(String id, Map<String, dynamic> map) => ProcurementFamily(
    id: id,
    institutionId: map['institutionId'] ?? '',
    name: map['name'] ?? '',
  );
}

class ProcurementSubfamily {
  final String id;
  final String familyId;
  final String name;

  ProcurementSubfamily({required this.id, required this.familyId, required this.name});

  Map<String, dynamic> toMap() => {'familyId': familyId, 'name': name};
  factory ProcurementSubfamily.fromMap(String id, Map<String, dynamic> map) => ProcurementSubfamily(
    id: id,
    familyId: map['familyId'] ?? '',
    name: map['name'] ?? '',
  );
}

class Warehouse {
  final String id;
  final String institutionId;
  final String name;
  final String location;

  Warehouse({required this.id, required this.institutionId, required this.name, this.location = ''});

  Map<String, dynamic> toMap() => {
    'id': id,
    'institutionId': institutionId,
    'name': name,
    'location': location,
  };
  factory Warehouse.fromMap(String id, Map<String, dynamic> map) => Warehouse(
    id: id,
    institutionId: map['institutionId'] ?? '',
    name: map['name'] ?? '',
    location: map['location'] ?? '',
  );
}

class ProcurementItem {
  final String id;
  final String institutionId;
  final String name;
  final ProcurementCategory category;
  final String description;
  final String composition;
  final String? familyId;
  final String? subfamilyId;
  final List<String> availableColors;
  final List<String> availableSizes;
  final double price;
  final double costPrice;
  final String? imageUrl;
  final String reference;
  final double minSafetyStock;
  final Map<String, double> variantSafetyStocks; // Key: "size_color"
  final bool isActive;
  final bool isDiscontinued;

  ProcurementItem({
    required this.id,
    required this.institutionId,
    required this.name,
    this.category = ProcurementCategory.uniform,
    this.description = '',
    this.composition = '',
    this.familyId,
    this.subfamilyId,
    this.availableColors = const [],
    this.availableSizes = const [],
    required this.price,
    this.costPrice = 0.0,
    this.imageUrl,
    this.reference = '',
    this.minSafetyStock = 5.0,
    this.variantSafetyStocks = const {},
    this.isActive = true,
    this.isDiscontinued = false,
  });

  List<ProcurementVariant> get variants {
    List<ProcurementVariant> list = [];
    for (var s in availableSizes) {
      for (var c in availableColors) {
        list.add(ProcurementVariant(size: s, color: c));
      }
    }
    // If no sizes/colors defined, return at least one "N/A" variant if needed, 
    // but the app logic usually enforces selection.
    if (list.isEmpty) {
      if (availableSizes.isEmpty && availableColors.isEmpty) {
         list.add(ProcurementVariant(size: 'U', color: 'N/A'));
      } else if (availableSizes.isEmpty) {
        for (var c in availableColors) list.add(ProcurementVariant(size: 'U', color: c));
      } else if (availableColors.isEmpty) {
        for (var s in availableSizes) list.add(ProcurementVariant(size: s, color: 'N/A'));
      }
    }
    return list;
  }

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'name': name,
    'category': category.name,
    'description': description,
    'composition': composition,
    'familyId': familyId,
    'subfamilyId': subfamilyId,
    'availableColors': availableColors,
    'availableSizes': availableSizes,
    'price': price,
    'costPrice': costPrice,
    'imageUrl': imageUrl,
    'reference': reference,
    'minSafetyStock': minSafetyStock,
    'variantSafetyStocks': variantSafetyStocks,
    'isActive': isActive,
    'isDiscontinued': isDiscontinued,
  };

  factory ProcurementItem.fromMap(String id, Map<String, dynamic> map) => ProcurementItem(
    id: id,
    institutionId: map['institutionId'] ?? '',
    name: map['name'] ?? '',
    category: ProcurementCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => ProcurementCategory.uniform),
    description: map['description'] ?? '',
    composition: map['composition'] ?? '',
    familyId: map['familyId'],
    subfamilyId: map['subfamilyId'],
    availableColors: List<String>.from(map['availableColors'] ?? []),
    availableSizes: List<String>.from(map['availableSizes'] ?? []),
    price: (map['price'] ?? 0.0).toDouble(),
    costPrice: (map['costPrice'] ?? 0.0).toDouble(),
    imageUrl: map['imageUrl'],
    reference: map['reference'] ?? '',
    minSafetyStock: (map['minSafetyStock'] ?? 5.0).toDouble(),
    variantSafetyStocks: (map['variantSafetyStocks'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
    isActive: map['isActive'] ?? true,
    isDiscontinued: map['isDiscontinued'] ?? false,
  );
}

class ProcurementStock {
  final String itemId;
  final String size;
  final String color;
  final String warehouseId;
  final double quantity;

  ProcurementStock({
    required this.itemId,
    required this.size,
    this.color = 'N/A',
    required this.warehouseId,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'size': size,
    'color': color,
    'warehouseId': warehouseId,
    'quantity': quantity,
  };

  factory ProcurementStock.fromMap(String id, Map<String, dynamic> map) => ProcurementStock(
    itemId: map['itemId'] ?? '',
    size: map['size'] ?? '',
    color: map['color'] ?? 'N/A',
    warehouseId: map['warehouseId'] ?? '',
    quantity: (map['quantity'] ?? 0.0).toDouble(),
  );
}

class SupplyEntry {
  final String id;
  final String institutionId;
  final String supplierName;
  final String warehouseId;
  final DateTime intakeDate;
  final List<OrderItemDetails> items;
  final String invoiceNumber;

  final String? purchaseOrderId;

  SupplyEntry({
    required this.id,
    required this.institutionId,
    required this.supplierName,
    required this.warehouseId,
    required this.intakeDate,
    required this.items,
    required this.invoiceNumber,
    this.purchaseOrderId,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'supplierName': supplierName,
    'warehouseId': warehouseId,
    'intakeDate': Timestamp.fromDate(intakeDate),
    'items': items.map((e) => e.toMap()).toList(),
    'invoiceNumber': invoiceNumber,
    if (purchaseOrderId != null) 'purchaseOrderId': purchaseOrderId,
  };

  factory SupplyEntry.fromMap(String id, Map<String, dynamic> map) => SupplyEntry(
    id: id,
    institutionId: map['institutionId'] ?? '',
    supplierName: map['supplierName'] ?? '',
    warehouseId: map['warehouseId'] ?? '',
    intakeDate: (map['intakeDate'] as Timestamp).toDate(),
    items: (map['items'] as List? ?? []).map((e) => OrderItemDetails.fromMap(e)).toList(),
    invoiceNumber: map['invoiceNumber'] ?? '',
    purchaseOrderId: map['purchaseOrderId'],
  );
}

class ProcurementOrder {
  final String id;
  final String institutionId;
  final String customerId; 
  final String customerName;
  final DateTime orderDate;
  final List<OrderItemDetails> items;
  final OrderStatus status;
  final double totalAmount;
  final String? paymentTransactionId;
  final String? performedById;
  final String? performedByName;
  final String? invoiceUrl;

  ProcurementOrder({
    required this.id,
    required this.institutionId,
    required this.customerId,
    required this.customerName,
    required this.orderDate,
    required this.items,
    required this.status,
    required this.totalAmount,
    this.paymentTransactionId,
    this.performedById,
    this.performedByName,
    this.invoiceUrl,
    this.invoiceNumber,
    this.invoiceNotes,
    this.invoiceAmount,
  });

  final String? invoiceNumber;
  final String? invoiceNotes;
  final double? invoiceAmount;

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'customerId': customerId,
    'customerName': customerName,
    'orderDate': Timestamp.fromDate(orderDate),
    'items': items.map((e) => e.toMap()).toList(),
    'status': status.name,
    'totalAmount': totalAmount,
    'paymentTransactionId': paymentTransactionId,
    if (performedById != null) 'performedById': performedById,
    if (performedByName != null) 'performedByName': performedByName,
    if (invoiceUrl != null) 'invoiceUrl': invoiceUrl,
    if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
    if (invoiceNotes != null) 'invoiceNotes': invoiceNotes,
    if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
  };

  factory ProcurementOrder.fromMap(String id, Map<String, dynamic> map) => ProcurementOrder(
    id: id,
    institutionId: map['institutionId'] ?? '',
    customerId: map['customerId'] ?? '',
    customerName: map['customerName'] ?? '',
    orderDate: (map['orderDate'] as Timestamp).toDate(),
    items: (map['items'] as List? ?? []).map((e) => OrderItemDetails.fromMap(e)).toList(),
    status: OrderStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => OrderStatus.pending),
    totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
    paymentTransactionId: map['paymentTransactionId'],
    performedById: map['performedById'],
    performedByName: map['performedByName'],
    invoiceUrl: map['invoiceUrl'],
    invoiceNumber: map['invoiceNumber'],
    invoiceNotes: map['invoiceNotes'],
    invoiceAmount: (map['invoiceAmount'] as num?)?.toDouble(),
  );
}

class OrderItemDetails {
  final String itemId;
  final String itemName;
  final String? itemReference;
  final String size;
  final String color;
  final int quantity;
  final int quantityReceived;
  final double unitPrice;
  final double? costPrice;

  OrderItemDetails({
    required this.itemId,
    required this.itemName,
    this.itemReference,
    required this.size,
    this.color = 'N/A',
    this.quantity = 1,
    this.quantityReceived = 0,
    required this.unitPrice,
    this.costPrice,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    if (itemReference != null) 'itemReference': itemReference,
    'size': size,
    'color': color,
    'quantity': quantity,
    'quantityReceived': quantityReceived,
    'unitPrice': unitPrice,
    if (costPrice != null) 'costPrice': costPrice,
  };

  factory OrderItemDetails.fromMap(Map<String, dynamic> map) => OrderItemDetails(
    itemId: map['itemId'] ?? '',
    itemName: map['itemName'] ?? '',
    itemReference: map['itemReference'],
    size: map['size'] ?? '',
    color: map['color'] ?? 'N/A',
    quantity: (map['quantity'] ?? 1).toInt(),
    quantityReceived: (map['quantityReceived'] ?? 0).toInt(),
    unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
    costPrice: (map['costPrice'] as num?)?.toDouble(),
  );
}

class ArticleProfit {
  final String itemId;
  final String itemName;
  final double quantitySold;
  final double totalRevenue;
  final double totalCost;
  final double averageCost;

  ArticleProfit({
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalCost,
    required this.averageCost,
  });

  double get netProfit => totalRevenue - totalCost;
  double get profitMargin => totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
}

class PurchaseOrder {
  final String id;
  final String institutionId;
  final String supplierName;
  final DateTime orderDate;
  final DateTime? negotiatedDeliveryDate;
  final List<OrderItemDetails> items;
  final String status; // 'draft', 'ordered', 'received', 'cancelled'
  final double totalAmount;

  PurchaseOrder({
    required this.id,
    required this.institutionId,
    this.supplierName = 'Fornecedor Principal',
    required this.orderDate,
    this.negotiatedDeliveryDate,
    required this.items,
    this.status = 'draft',
    this.totalAmount = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'supplierName': supplierName,
    'orderDate': Timestamp.fromDate(orderDate),
    if (negotiatedDeliveryDate != null) 'negotiatedDeliveryDate': Timestamp.fromDate(negotiatedDeliveryDate!),
    'items': items.map((e) => e.toMap()).toList(),
    'status': status,
    'totalAmount': totalAmount,
  };

  factory PurchaseOrder.fromMap(String id, Map<String, dynamic> map) => PurchaseOrder(
    id: id,
    institutionId: map['institutionId'] ?? '',
    supplierName: map['supplierName'] ?? 'Fornecedor Principal',
    orderDate: (map['orderDate'] as Timestamp).toDate(),
    negotiatedDeliveryDate: (map['negotiatedDeliveryDate'] as Timestamp?)?.toDate(),
    items: (map['items'] as List? ?? []).map((e) => OrderItemDetails.fromMap(e)).toList(),
    status: map['status'] ?? 'draft',
    totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
  );
}

class InventoryAuditLog {
  final String id;
  final String institutionId;
  final String itemId;
  final String itemName;
  final String size;
  final String color;
  final String warehouseId;
  final String userId;
  final String userName;
  final InventoryAction action;
  final double quantityChanged;
  final double resultingStock;
  final DateTime timestamp;
  final String? referenceId; 
  final String? itemReference;
  final String? notes;

  InventoryAuditLog({
    required this.id,
    required this.institutionId,
    required this.itemId,
    required this.itemName,
    required this.size,
    this.color = 'N/A',
    this.warehouseId = 'default',
    required this.userId,
    required this.userName,
    required this.action,
    required this.quantityChanged,
    required this.resultingStock,
    required this.timestamp,
    this.referenceId,
    this.itemReference,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'itemId': itemId,
    'itemName': itemName,
    'size': size,
    'color': color,
    'warehouseId': warehouseId,
    'userId': userId,
    'userName': userName,
    'action': action.name,
    'quantityChanged': quantityChanged,
    'resultingStock': resultingStock,
    'timestamp': Timestamp.fromDate(timestamp),
    'referenceId': referenceId,
    'itemReference': itemReference,
    'notes': notes,
  };

  factory InventoryAuditLog.fromMap(String id, Map<String, dynamic> map) => InventoryAuditLog(
    id: id,
    institutionId: map['institutionId'] ?? '',
    itemId: map['itemId'] ?? '',
    itemName: map['itemName'] ?? '',
    size: map['size'] ?? '',
    color: map['color'] ?? 'N/A',
    warehouseId: map['warehouseId'] ?? 'default',
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
    action: InventoryAction.values.firstWhere((e) => e.name == map['action'], orElse: () => InventoryAction.adjustment),
    quantityChanged: (map['quantityChanged'] ?? 0.0).toDouble(),
    resultingStock: (map['resultingStock'] ?? 0.0).toDouble(),
    timestamp: (map['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
    referenceId: map['referenceId'],
    itemReference: map['itemReference'],
    notes: map['notes'],
  );
}

enum InventoryAction {
  entry, 
  sale, 
  adjustment, 
  fulfillment, 
  cancellation,
  closing, 
  regularization,
}

class InventoryRegularization {
  final String id;
  final String institutionId;
  final String warehouseId;
  final DateTime date;
  final String reason;
  final List<RegularizationItem> items;
  final String status; // 'draft', 'finalized'
  final String? performedById;
  final String? performedByName;
  final DateTime createdAt;

  InventoryRegularization({
    required this.id,
    required this.institutionId,
    required this.warehouseId,
    required this.date,
    required this.reason,
    required this.items,
    this.status = 'draft',
    this.performedById,
    this.performedByName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'warehouseId': warehouseId,
    'date': Timestamp.fromDate(date),
    'reason': reason,
    'items': items.map((e) => e.toMap()).toList(),
    'status': status,
    'performedById': performedById,
    'performedByName': performedByName,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory InventoryRegularization.fromMap(String id, Map<String, dynamic> map) => InventoryRegularization(
    id: id,
    institutionId: map['institutionId'] ?? '',
    warehouseId: map['warehouseId'] ?? '',
    date: (map['date'] as Timestamp? ?? map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    reason: map['reason'] ?? '',
    items: (map['items'] as List? ?? []).map((e) => RegularizationItem.fromMap(e)).toList(),
    status: map['status'] ?? 'draft',
    performedById: map['performedById'],
    performedByName: map['performedByName'],
    createdAt: (map['createdAt'] as Timestamp? ?? map['date'] as Timestamp? ?? Timestamp.now()).toDate(),
  );
}

class RegularizationItem {
  final String itemId;
  final String itemName;
  final String? itemReference;
  final String size;
  final String color;
  final double quantity; // Can be positive (addition) or negative (subtraction)
  final double unitCost;

  RegularizationItem({
    required this.itemId,
    required this.itemName,
    this.itemReference,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitCost,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    if (itemReference != null) 'itemReference': itemReference,
    'size': size,
    'color': color,
    'quantity': quantity,
    'unitCost': unitCost,
  };

  factory RegularizationItem.fromMap(Map<String, dynamic> map) => RegularizationItem(
    itemId: map['itemId'] ?? '',
    itemName: map['itemName'] ?? '',
    itemReference: map['itemReference'],
    size: map['size'] ?? '',
    color: map['color'] ?? 'N/A',
    quantity: (map['quantity'] ?? 0.0).toDouble(),
    unitCost: (map['unitCost'] ?? 0.0).toDouble(),
  );
}

class InventoryClosing {
  final String id;
  final String institutionId;
  final DateTime closingDate;
  final String counterName;
  final String approverName;
  final DateTime createdAt;
  final Map<String, double> stockSnapshot; // Key: "itemId_size_color_warehouseId"

  InventoryClosing({
    required this.id,
    required this.institutionId,
    required this.closingDate,
    required this.counterName,
    required this.approverName,
    required this.createdAt,
    required this.stockSnapshot,
  });

  Map<String, dynamic> toMap() => {
    'institutionId': institutionId,
    'closingDate': Timestamp.fromDate(closingDate),
    'counterName': counterName,
    'approverName': approverName,
    'createdAt': Timestamp.fromDate(createdAt),
    'stockSnapshot': stockSnapshot,
  };

  factory InventoryClosing.fromMap(String id, Map<String, dynamic> map) => InventoryClosing(
    id: id,
    institutionId: map['institutionId'] ?? '',
    closingDate: (map['closingDate'] as Timestamp? ?? map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    counterName: map['counterName'] ?? '',
    approverName: map['approverName'] ?? '',
    createdAt: (map['createdAt'] as Timestamp? ?? map['closingDate'] as Timestamp? ?? Timestamp.now()).toDate(),
    stockSnapshot: (map['stockSnapshot'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
  );
}
