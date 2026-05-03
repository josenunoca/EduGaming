import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../models/institution_model.dart';
import '../models/user_model.dart';
import '../models/procurement/procurement_models.dart';
import '../models/procurement/stock_batch_model.dart';
import '../models/finance/finance_models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class ProcurementService {
  final FirebaseService _firebaseService;
  final NotificationService _notifications;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseFirestore get db => _db;

  ProcurementService(this._firebaseService, this._notifications);

  // --- Permission Helpers ---

  bool _isSuperAdmin(UserModel user, InstitutionModel institution) {
    return user.role == UserRole.institution || user.id == institution.id;
  }

  bool canFulfillOrders(UserModel user, InstitutionModel institution) {
    if (_isSuperAdmin(user, institution)) return true;
    final delegates = institution.delegatedRoles['procurement:fulfillment'] ?? [];
    return delegates.contains(user.id);
  }

  bool canInvoiceOrders(UserModel user, InstitutionModel institution) {
    if (_isSuperAdmin(user, institution)) return true;
    final delegates = institution.delegatedRoles['procurement:invoicing'] ?? [];
    return delegates.contains(user.id);
  }

  bool canManageStockGlobally(UserModel user, InstitutionModel institution) {
    if (_isSuperAdmin(user, institution)) return true;
    final delegates = institution.delegatedRoles['procurement:stock_global'] ?? [];
    return delegates.contains(user.id);
  }

  bool canManageStockForWarehouse(UserModel user, InstitutionModel institution, String warehouseId) {
    if (canManageStockGlobally(user, institution)) return true;
    final delegates = institution.delegatedRoles['procurement:stock_warehouse:$warehouseId'] ?? [];
    return delegates.contains(user.id);
  }

  // --- Article Management ---

  Future<String> uploadItemImage(String institutionId, String itemId, Uint8List bytes) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('institutions')
        .child(institutionId)
        .child('procurement')
        .child('$itemId.jpg');
    
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> _checkInventoryLock(String institutionId, DateTime movementDate) async {
    final closing = await getLatestInventoryClosing(institutionId);
    if (closing != null && movementDate.isBefore(closing.closingDate)) {
      throw Exception('Não é possível realizar movimentos com data anterior ao último fecho de inventário (${DateFormat('dd/MM/yyyy').format(closing.closingDate)}).');
    }
  }

  Future<InventoryClosing?> getLatestInventoryClosing(String institutionId) async {
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_closings')
        .orderBy('closingDate', descending: true)
        .limit(1)
        .get();
    
    if (snap.docs.isEmpty) return null;
    return InventoryClosing.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<void> closeInventory({
    required String institutionId,
    required DateTime closingDate,
    required String counterName,
    required String approverName,
  }) async {
    // 1. Get current stock snapshot
    final stockSnap = await _db.collection('institutions').doc(institutionId).collection('procurement_stock').get();
    Map<String, double> snapshot = {};
    for (var doc in stockSnap.docs) {
      snapshot[doc.id] = (doc.data()['quantity'] ?? 0.0).toDouble();
    }

    // 2. Save closing record
    final closingId = const Uuid().v4();
    final closing = InventoryClosing(
      id: closingId,
      institutionId: institutionId,
      closingDate: closingDate,
      counterName: counterName,
      approverName: approverName,
      createdAt: DateTime.now(),
      stockSnapshot: snapshot,
    );

    await _db.collection('institutions').doc(institutionId).collection('procurement_closings').doc(closingId).set(closing.toMap());

    // 3. Log the closing action
    await _db.collection('institutions').doc(institutionId).collection('procurement_audit_logs').add({
      'institutionId': institutionId,
      'action': InventoryAction.closing.name,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': 'Inventário fechado em ${DateFormat('dd/MM/yyyy').format(closingDate)} por $counterName. Aprovado por $approverName.',
    });
  }

  Future<String> _archiveInvoice(String institutionId, String orderId, Uint8List pdfBytes) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('institutions')
        .child(institutionId)
        .child('procurement_docs')
        .child('invoice_$orderId.pdf');
    
    await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    return await ref.getDownloadURL();
  }

  Stream<List<ProcurementItem>> getItems(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_items')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ProcurementItem.fromMap(doc.id, doc.data())).toList());
  }

  Future<bool> isReferenceUnique(String institutionId, String reference, {String? excludeItemId}) async {
    if (reference.isEmpty) return true;
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_items')
        .where('reference', isEqualTo: reference)
        .get();
    
    if (excludeItemId != null) {
      return snap.docs.every((doc) => doc.id == excludeItemId);
    }
    return snap.docs.isEmpty;
  }

  Future<void> saveItem(ProcurementItem item) async {
    // Check reference uniqueness if provided
    if (item.reference.isNotEmpty) {
      final isUnique = await isReferenceUnique(item.institutionId, item.reference, excludeItemId: item.id);
      if (!isUnique) throw Exception('Já existe um artigo com a referência "${item.reference}".');
    }

    await _checkInventoryLock(item.institutionId, DateTime.now());

    await _db
        .collection('institutions')
        .doc(item.institutionId)
        .collection('procurement_items')
        .doc(item.id)
        .set(item.toMap());
  }

  Future<void> deleteItem(String institutionId, String itemId) async {
    // 1. Check for batches (entries)
    final batches = await _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches')
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();
    
    if (batches.docs.isNotEmpty) {
      throw Exception('Não é possível eliminar um artigo com histórico de movimentos (entradas).');
    }

    // 2. Check for orders (sales) - Requires indexing itemIds in orders
    final orders = await _db.collection('institutions').doc(institutionId).collection('procurement_orders')
        .where('itemIds', arrayContains: itemId)
        .limit(1)
        .get();

    if (orders.docs.isNotEmpty) {
      throw Exception('Não é possível eliminar um artigo com histórico de movimentos (vendas).');
    }
    
    await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).delete();
  }

  Future<void> discontinueItem(String institutionId, String itemId, bool discontinued) async {
    await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).update({
      'isDiscontinued': discontinued,
    });
  }

  // --- Hierarchy & Warehouses ---

  Stream<List<ProcurementFamily>> getFamilies(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_families')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ProcurementFamily.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveFamily(ProcurementFamily family) async {
    await _db
        .collection('institutions')
        .doc(family.institutionId)
        .collection('procurement_families')
        .doc(family.id)
        .set(family.toMap());
  }

  Stream<List<ProcurementSubfamily>> getSubfamilies(String institutionId, String familyId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_families')
        .doc(familyId)
        .collection('procurement_subfamilies')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ProcurementSubfamily.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveSubfamily(String institutionId, ProcurementSubfamily subfamily) async {
     await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_families')
        .doc(subfamily.familyId)
        .collection('procurement_subfamilies')
        .doc(subfamily.id)
        .set(subfamily.toMap());
  }

  Stream<List<Warehouse>> getWarehouses(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_warehouses')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Warehouse.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveWarehouse(Warehouse warehouse) async {
    await _db
        .collection('institutions')
        .doc(warehouse.institutionId)
        .collection('procurement_warehouses')
        .doc(warehouse.id)
        .set(warehouse.toMap());
  }

  // --- Stock Logic ---

  Stream<List<ProcurementStock>> getStockStream(String institutionId, {String? itemId, String? warehouseId}) {
    Query<Map<String, dynamic>> query = _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_stock');
    
    if (itemId != null) query = query.where('itemId', isEqualTo: itemId);
    if (warehouseId != null) query = query.where('warehouseId', isEqualTo: warehouseId);

    return query.snapshots().map((snap) => snap.docs.map((doc) => ProcurementStock.fromMap(doc.id, doc.data())).toList());
  }

  // --- Alerts & Reports ---

  Future<List<Map<String, dynamic>>> getLowStockAlerts(String institutionId) async {
    final itemsSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_items')
        .get();
    
    final items = itemsSnapshot.docs.map((doc) => ProcurementItem.fromMap(doc.id, doc.data())).toList();
    List<Map<String, dynamic>> alerts = [];

    // Fetch pending purchase orders to track what's coming
    final poSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_purchase_orders')
        .where('status', isEqualTo: 'ordered')
        .get();
    
    final pendingOrders = poSnapshot.docs.map((doc) => PurchaseOrder.fromMap(doc.id, doc.data())).toList();
    
    // Map of itemId -> size -> quantity on order
    Map<String, Map<String, int>> onOrderMap = {};
    for (var po in pendingOrders) {
      for (var item in po.items) {
        onOrderMap.putIfAbsent(item.itemId, () => {});
        onOrderMap[item.itemId]![item.size] = (onOrderMap[item.itemId]![item.size] ?? 0) + item.quantity;
      }
    }

    for (var item in items) {
      final stockSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_stock')
          .where('itemId', isEqualTo: item.id)
          .get();
      
      // Map of "size_color" -> quantity
      Map<String, double> variantStock = {};
      for (var doc in stockSnapshot.docs) {
        final stock = ProcurementStock.fromMap(doc.id, doc.data());
        final key = "${stock.size}_${stock.color}";
        variantStock[key] = (variantStock[key] ?? 0) + stock.quantity;
      }

      // Generate all possible variants based on item definition
      List<String> variants = [];
      for (var s in item.availableSizes) {
        for (var c in item.availableColors) {
          variants.add("${s}_${c}");
        }
      }
      
      // Also consider variants that might exist in stock but not in current item definition
      final allKnownVariants = {...variantStock.keys, ...variants};

      for (var variantKey in allKnownVariants) {
        final parts = variantKey.split('_');
        final size = parts[0];
        final color = parts.length > 1 ? parts[1] : 'N/A';
        
        final currentStock = variantStock[variantKey] ?? 0;
        final onOrder = onOrderMap[item.id]?[size] ?? 0; // Note: POs currently don't always have color in key, using size for now or fixing POs
        
        // Safety Stock Logic: Specific Variant -> Item Global
        final safetyStock = item.variantSafetyStocks[variantKey] ?? item.minSafetyStock;
        
        if (currentStock <= safetyStock) {
          alerts.add({
            'item': item,
            'size': size,
            'color': color,
            'currentStock': currentStock,
            'onOrder': onOrder,
            'suggestedOrder': (safetyStock * 2) - currentStock - onOrder,
            'type': 'critical',
          });
        } 
        else if (currentStock <= safetyStock + 5) {
          alerts.add({
            'item': item,
            'size': size,
            'color': color,
            'currentStock': currentStock,
            'onOrder': onOrder,
            'suggestedOrder': (safetyStock * 2) - currentStock - onOrder,
            'type': 'warning',
          });
        }
      }
    }
    // Sort alerts: critical first, then by suggested order quantity
    alerts.sort((a, b) {
      if (a['type'] == 'critical' && b['type'] == 'warning') return -1;
      if (a['type'] == 'warning' && b['type'] == 'critical') return 1;
      return (b['suggestedOrder'] as double).compareTo(a['suggestedOrder'] as double);
    });

    return alerts.where((a) => (a['suggestedOrder'] as double) > 0 || (a['currentStock'] as double) <= (a['item'] as ProcurementItem).minSafetyStock).toList();
  }

  Future<double> getFIFOCostPrice({
    required String institutionId,
    required String itemId,
    required String size,
    required String color,
    required String warehouseId,
  }) async {
    // Query with equality only to avoid composite index
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches')
        .where('itemId', isEqualTo: itemId)
        .where('size', isEqualTo: size)
        .where('color', isEqualTo: color)
        .where('warehouseId', isEqualTo: warehouseId)
        .get();
    
    if (snap.docs.isNotEmpty) {
      // Filter and sort locally
      final batches = snap.docs.map((d) => d.data())
          .where((data) => (data['remainingQuantity'] ?? 0.0) > 0)
          .toList();
      
      if (batches.isNotEmpty) {
        batches.sort((a, b) {
          final aDate = (a['date'] ?? a['createdAt'] ?? Timestamp.now()) as Timestamp;
          final bDate = (b['date'] ?? b['createdAt'] ?? Timestamp.now()) as Timestamp;
          return aDate.compareTo(bDate);
        });
        return (batches.first['unitCost'] ?? 0.0).toDouble();
      }
    }
    
    // Fallback to item's costPrice
    final itemDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).get();
    final data = itemDoc.data();
    return (data != null ? (data['costPrice'] ?? 0.0) : 0.0).toDouble();
  }

  Future<void> adjustStock({
    required String institutionId,
    required String itemId,
    required String itemName,
    required String size,
    required String color,
    required String warehouseId,
    required double quantityDelta,
    required String reason,
    required String notes,
    required String userId,
    required String userName,
  }) async {
    await _checkInventoryLock(institutionId, DateTime.now());
    final batch = _db.batch();

    // 1. Update main stock record
    final stockDoc = _db.collection('institutions').doc(institutionId).collection('procurement_stock')
        .doc('${itemId}_${warehouseId}_${size}_${color}');
    
    final stockSnap = await stockDoc.get();
    double currentTotal = 0;
    if (stockSnap.exists) {
      currentTotal = (stockSnap.data()!['quantity'] ?? 0.0).toDouble();
    }

    final newTotal = currentTotal + quantityDelta;
    batch.set(stockDoc, {
      'itemId': itemId,
      'size': size,
      'color': color,
      'warehouseId': warehouseId,
      'quantity': newTotal,
    }, SetOptions(merge: true));

    // 2. Handle FIFO batches for decreases
    if (quantityDelta < 0) {
      double toConsume = -quantityDelta;
      final batchesSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches')
          .where('itemId', isEqualTo: itemId)
          .where('size', isEqualTo: size)
          .where('color', isEqualTo: color)
          .where('warehouseId', isEqualTo: warehouseId)
          .get();

      // Filter and sort locally to avoid composite index requirement
      final sortedDocs = batchesSnapshot.docs.where((d) => (d.data()['remainingQuantity'] ?? 0.0) > 0).toList()
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = (aData['date'] ?? aData['createdAt'] ?? Timestamp.now()) as Timestamp;
          final bDate = (bData['date'] ?? bData['createdAt'] ?? Timestamp.now()) as Timestamp;
          return aDate.compareTo(bDate);
        });

      for (var doc in sortedDocs) {
        if (toConsume <= 0) break;
        final batchData = doc.data();
        double remaining = (batchData['remainingQuantity'] ?? 0.0).toDouble();
        
        if (remaining <= toConsume) {
          batch.update(doc.reference, {'remainingQuantity': 0});
          toConsume -= remaining;
        } else {
          batch.update(doc.reference, {'remainingQuantity': remaining - toConsume});
          toConsume = 0;
        }
      }
    } else if (quantityDelta > 0) {
      // For increases (sobras), we create a dummy batch with 0 cost or current avg cost
      final itemDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).get();
      final item = ProcurementItem.fromMap(itemId, itemDoc.data()!);
      
      final newBatchRef = _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches').doc();
      batch.set(newBatchRef, {
        'itemId': itemId,
        'size': size,
        'color': color,
        'warehouseId': warehouseId,
        'originalQuantity': quantityDelta,
        'remainingQuantity': quantityDelta,
        'unitCost': item.costPrice,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 3. Create Audit Log
    final logRef = _db.collection('institutions').doc(institutionId).collection('procurement_audit_logs').doc();
    batch.set(logRef, {
      'institutionId': institutionId,
      'itemId': itemId,
      'itemName': itemName,
      'size': size,
      'color': color,
      'warehouseId': warehouseId,
      'userId': userId,
      'userName': userName,
      'action': 'adjustment',
      'quantityChanged': quantityDelta,
      'resultingStock': newTotal,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': '[$reason] $notes',
    });

    await batch.commit();
  }

  Future<List<ArticleProfit>> getProfitReport(String institutionId) async {
    final ordersSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_orders')
        .where('status', whereIn: ['delivered', 'invoiced'])
        .get();

    Map<String, ArticleProfit> profitMap = {};

    for (var doc in ordersSnapshot.docs) {
      final order = ProcurementOrder.fromMap(doc.id, doc.data());
      for (var item in order.items) {
        if (!profitMap.containsKey(item.itemId)) {
          profitMap[item.itemId] = ArticleProfit(
            itemId: item.itemId,
            itemName: item.itemName,
            quantitySold: 0,
            totalRevenue: 0,
            totalCost: 0,
            averageCost: 0,
          );
        }
        final p = profitMap[item.itemId]!;
        final newQty = p.quantitySold + item.quantity;
        // Use the recorded costPrice from the order item (which is set during FIFO fulfillment)
        final itemCost = (item.costPrice ?? 0) * item.quantity;
        final newCost = p.totalCost + itemCost;
        
        profitMap[item.itemId] = ArticleProfit(
          itemId: p.itemId,
          itemName: p.itemName,
          quantitySold: newQty,
          totalRevenue: p.totalRevenue + (item.unitPrice * item.quantity),
          totalCost: newCost,
          averageCost: newQty > 0 ? newCost / newQty : 0,
        );
      }
    }
    return profitMap.values.toList();
  }

  Future<Map<String, dynamic>> getWarehouseStockValuation(String institutionId) async {
    // FIFO Valuation: Sum of (remainingQuantity * unitCost) from all batches
    final batchesSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches')
        .where('remainingQuantity', isGreaterThan: 0)
        .get();
        
    final itemsSnapshot = await _db.collection('institutions').doc(institutionId).collection('procurement_items').get();
    final items = itemsSnapshot.docs.map((d) => ProcurementItem.fromMap(d.id, d.data())).toList();

    double totalCost = 0.0;
    double totalSale = 0.0;
    double totalQty = 0.0;

    for (var doc in batchesSnapshot.docs) {
      final batch = StockBatch.fromMap(doc.id, doc.data());
      final item = items.where((i) => i.id == batch.itemId).firstOrNull;
      
      totalCost += batch.remainingQuantity * batch.unitCost;
      totalSale += batch.remainingQuantity * (item?.price ?? 0.0);
      totalQty += batch.remainingQuantity;
    }

    return {
      'totalCost': totalCost,
      'totalSale': totalSale,
      'totalQty': totalQty,
    };
  }

  Stream<Map<String, dynamic>> getInventorySummaryStream(String institutionId) {
    final stockStream = _db.collection('institutions').doc(institutionId).collection('procurement_stock').snapshots();
    final batchesStream = _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches').snapshots();
    final itemsStream = _db.collection('institutions').doc(institutionId).collection('procurement_items').snapshots();

    return Rx.combineLatest3(
      stockStream,
      batchesStream,
      itemsStream,
      (QuerySnapshot stockSnap, QuerySnapshot batchesSnap, QuerySnapshot itemsSnap) {
        final items = itemsSnap.docs.map((d) => ProcurementItem.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
        final batches = batchesSnap.docs
            .map((d) => StockBatch.fromMap(d.id, d.data() as Map<String, dynamic>))
            .where((b) => b.remainingQuantity > 0)
            .toList();
        
        double totalQty = 0.0;
        double totalSale = 0.0;
        double totalCost = 0.0;

        // Calculate Total Qty and Sale Value from aggregated stock
        for (var doc in stockSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final qty = (data['quantity'] ?? 0.0).toDouble();
          final itemId = data['itemId'] as String;
          final item = items.where((i) => i.id == itemId).firstOrNull;

          totalQty += qty;
          totalSale += qty * (item?.price ?? 0.0);
        }

        // Calculate Cost Value using batches + fallback to item default cost for unbatched stock
        // First, sum costs from batches
        for (var batch in batches) {
          totalCost += batch.remainingQuantity * batch.unitCost;
        }

        // Second, find if there is stock in 'procurement_stock' that isn't accounted for in batches
        // (This happens for stock registered before the FIFO/Batch system was implemented)
        for (var doc in stockSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final totalStockQty = (data['quantity'] ?? 0.0).toDouble();
          final itemId = data['itemId'] as String;
          final size = data['size'] as String;
          final color = data['color'] as String;

          final batchedQty = batches
              .where((b) => b.itemId == itemId && b.size == size && b.color == color)
              .fold<double>(0.0, (acc, b) => acc + b.remainingQuantity);

          if (totalStockQty > batchedQty) {
            final unbatchedQty = totalStockQty - batchedQty;
            final item = items.where((i) => i.id == itemId).firstOrNull;
            totalCost += unbatchedQty * (item?.costPrice ?? 0.0);
          }
        }

        return {
          'totalQty': totalQty,
          'totalCost': totalCost,
          'totalSale': totalSale,
        };
      },
    );
  }

  Stream<List<SupplyEntry>> getSupplyEntries(String institutionId) {
    return _db.collection('institutions').doc(institutionId).collection('procurement_entries')
        .orderBy('intakeDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SupplyEntry.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<PurchaseOrder>> getPurchaseOrders(String institutionId) {
    return _db.collection('institutions').doc(institutionId).collection('procurement_purchase_orders')
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PurchaseOrder.fromMap(doc.id, doc.data())).toList());
  }


  Future<void> savePurchaseOrder(PurchaseOrder order) async {
    await _db.collection('institutions').doc(order.institutionId).collection('procurement_purchase_orders').doc(order.id).set(order.toMap());
  }

  Future<void> deletePurchaseOrder(String institutionId, String orderId) async {
    await _db.collection('institutions').doc(institutionId).collection('procurement_purchase_orders').doc(orderId).delete();
  }

  Future<void> generatePurchaseOrderPdf(PurchaseOrder order, String institutionName) async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(institutionName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('NOTA DE ENCOMENDA ADJUDICADA', style: pw.TextStyle(fontSize: 16, color: PdfColors.blue700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Nº PO: ${order.id.substring(0, 8).toUpperCase()}'),
                      pw.Text('Data: ${formatter.format(order.orderDate)}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FORNECEDOR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(order.supplierName),
                  ],
                ),
              ),
              if (order.negotiatedDeliveryDate != null) ...[
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Prazo de Entrega Acordado: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(formatter.format(order.negotiatedDeliveryDate!)),
                  ],
                ),
              ],
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                headers: ['Ref', 'Artigo', 'Tamanho/Cor', 'Qtd', 'Preço Unit.', 'Subtotal'],
                data: order.items.map((item) => [
                  item.itemReference ?? '-',
                  item.itemName,
                  '${item.size} / ${item.color}',
                  item.quantity.toString(),
                  '${(item.unitPrice).toStringAsFixed(2)} EUR',
                  '${(item.unitPrice * item.quantity).toStringAsFixed(2)} EUR',
                ]).toList(),
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Row(
                      children: [
                        pw.Text('TOTAL DA ENCOMENDA: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${order.totalAmount.toStringAsFixed(2)} EUR', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.SizedBox(height: 40),
                    pw.SizedBox(width: 150, child: pw.Divider()),
                    pw.Text('Aprovação Institucional', style: const pw.TextStyle(fontSize: 8)),
                  ]),
                  pw.Text('Gerado por EduGaming Aprovisionamento Pro', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'GuiaRemessa_${order.id.substring(0,8)}.pdf');
  }

  Stream<List<InventoryAuditLog>> getAuditLogs(String institutionId, {InventoryAction? action}) {
    // Query without orderBy/where combination to avoid composite index requirement
    return _db.collection('institutions').doc(institutionId).collection('procurement_audit')
        .snapshots()
        .map((snap) {
          var logs = snap.docs.map((d) => InventoryAuditLog.fromMap(d.id, d.data())).toList();
          
          // Filter locally
          if (action != null) {
            logs = logs.where((l) => l.action == action).toList();
          }
          
          // Sort locally
          logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return logs;
        });
  }

  Stream<double> getStockLevel(String institutionId, String itemId, {String? size, String? color, String? warehouseId}) {
    var query = _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_stock')
        .where('itemId', isEqualTo: itemId);
    
    if (size != null) query = query.where('size', isEqualTo: size);
    if (color != null) query = query.where('color', isEqualTo: color);
    if (warehouseId != null) query = query.where('warehouseId', isEqualTo: warehouseId);

    return query.snapshots().map((snap) {
      return snap.docs.fold<double>(0.0, (acc, doc) => acc + (doc.data()['quantity'] ?? 0.0).toDouble());
    });
  }

  Stream<double> getAvailableStockLevel(String institutionId, String itemId, {String? size, String? color}) {
    final physicalStockStream = getStockLevel(institutionId, itemId, size: size, color: color);
    
    // We listen to all orders for this institution that contain the itemId and are not terminal
    final pendingOrdersStream = _db.collection('institutions')
        .doc(institutionId)
        .collection('procurement_orders')
        .where('status', whereIn: [
          OrderStatus.pending.name,
          OrderStatus.paid.name,
          OrderStatus.preparing.name,
          OrderStatus.ready.name,
        ])
        .where('itemIds', arrayContains: itemId)
        .snapshots();

    return Rx.combineLatest2(physicalStockStream, pendingOrdersStream, (double physical, QuerySnapshot ordersSnap) {
      double pendingQty = 0;
      for (var doc in ordersSnap.docs) {
        final order = ProcurementOrder.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        for (var item in order.items) {
          if (item.itemId == itemId && 
              (size == null || item.size == size) && 
              (color == null || item.color == color)) {
            pendingQty += item.quantity;
          }
        }
      }
      final available = physical - pendingQty;
      return available < 0 ? 0.0 : available;
    });
  }

  Future<void> loadSupplyEntry(UserModel performer, SupplyEntry entry) async {
    // Check if any item is discontinued
    for (var item in entry.items) {
      final itemDoc = await _db.collection('institutions').doc(entry.institutionId).collection('procurement_items').doc(item.itemId).get();
      if (itemDoc.exists && (itemDoc.data()?['isDiscontinued'] ?? false)) {
        throw Exception('Não é possível dar entrada do artigo "${item.itemName}" porque está descontinuado.');
      }
    }

    final batch = _db.batch();
    
    for (var itemDetails in entry.items) {
      final stockDocId = '${itemDetails.itemId}_${itemDetails.size}_${itemDetails.color}_${entry.warehouseId}';
      final stockRef = _db
          .collection('institutions')
          .doc(entry.institutionId)
          .collection('procurement_stock')
          .doc(stockDocId);
      
      final stockDoc = await stockRef.get();
      final currentQty = (stockDoc.data()?['quantity'] ?? 0.0).toDouble();
      final newQty = currentQty + itemDetails.quantity;
      
      batch.set(stockRef, {
        'itemId': itemDetails.itemId,
        'size': itemDetails.size,
        'color': itemDetails.color,
        'warehouseId': entry.warehouseId,
        'quantity': newQty,
      }, SetOptions(merge: true));

      // Create Stock Batch for FIFO
      final batchRef = _db.collection('institutions').doc(entry.institutionId).collection('procurement_stock_batches').doc();
      final stockBatch = StockBatch(
        id: batchRef.id,
        institutionId: entry.institutionId,
        itemId: itemDetails.itemId,
        size: itemDetails.size,
        color: itemDetails.color,
        warehouseId: entry.warehouseId,
        originalQuantity: itemDetails.quantity.toDouble(),
        remainingQuantity: itemDetails.quantity.toDouble(),
        unitCost: itemDetails.costPrice ?? 0.0,
        createdAt: entry.intakeDate,
        entryId: entry.id,
      );
      batch.set(batchRef, stockBatch.toMap());

      final log = InventoryAuditLog(
        id: const Uuid().v4(),
        institutionId: entry.institutionId,
        itemId: itemDetails.itemId,
        itemName: itemDetails.itemName,
        size: itemDetails.size,
        color: itemDetails.color,
        warehouseId: entry.warehouseId,
        userId: performer.id,
        userName: performer.name,
        action: InventoryAction.entry,
        quantityChanged: itemDetails.quantity.toDouble(),
        resultingStock: newQty,
        timestamp: DateTime.now(),
        referenceId: itemDetails.itemReference ?? entry.id,
        notes: 'Entrada Fornecedor: ${entry.supplierName} - Fatura: ${entry.invoiceNumber}',
      );
      _logMovement(batch, log);
    }

    // --- Purchase Order Fulfillment Logic ---
    if (entry.purchaseOrderId != null) {
      final poRef = _db.collection('institutions').doc(entry.institutionId).collection('procurement_purchase_orders').doc(entry.purchaseOrderId);
      final poSnap = await poRef.get();
      if (poSnap.exists) {
        final po = PurchaseOrder.fromMap(poSnap.id, poSnap.data()!);
        List<OrderItemDetails> updatedItems = [];
        bool allFulfilled = true;

        for (var poItem in po.items) {
          int receivedNow = 0;
          // Find matching item in the entry
          for (var entryItem in entry.items) {
            if (entryItem.itemId == poItem.itemId && entryItem.size == poItem.size && entryItem.color == poItem.color) {
              receivedNow += entryItem.quantity;
            }
          }

          final newReceivedQty = poItem.quantityReceived + receivedNow;
          updatedItems.add(OrderItemDetails(
            itemId: poItem.itemId,
            itemName: poItem.itemName,
            itemReference: poItem.itemReference,
            size: poItem.size,
            color: poItem.color,
            quantity: poItem.quantity,
            quantityReceived: newReceivedQty,
            unitPrice: poItem.unitPrice,
            costPrice: poItem.costPrice,
          ));

          if (newReceivedQty < poItem.quantity) {
            allFulfilled = false;
          }
        }

        batch.update(poRef, {
          'items': updatedItems.map((e) => e.toMap()).toList(),
          'status': allFulfilled ? 'received' : 'ordered',
        });
      }
    }

    final entryRef = _db
        .collection('institutions')
        .doc(entry.institutionId)
        .collection('procurement_entries')
        .doc(entry.id);
    batch.set(entryRef, entry.toMap());

    await batch.commit();
  }

  Future<void> updateSupplyEntry(UserModel performer, SupplyEntry entry) async {
    final batch = _db.batch();
    
    // 0. Fetch the old entry to calculate deltas
    final oldEntryDoc = await _db.collection('institutions').doc(entry.institutionId).collection('procurement_entries').doc(entry.id).get();
    if (!oldEntryDoc.exists) return;
    final oldEntry = SupplyEntry.fromMap(oldEntryDoc.id, oldEntryDoc.data()!);

    // 1. Update the entry itself
    final entryRef = _db.collection('institutions').doc(entry.institutionId).collection('procurement_entries').doc(entry.id);
    batch.set(entryRef, entry.toMap());

    // 2. Process each item for stock and batch updates
    for (var newItem in entry.items) {
      final oldItem = oldEntry.items.where((i) => i.itemId == newItem.itemId && i.size == newItem.size && i.color == newItem.color).firstOrNull;
      final double qtyDelta = newItem.quantity.toDouble() - (oldItem?.quantity.toDouble() ?? 0.0);

      // Update the associated batch
      final batchesSnapshot = await _db.collection('institutions')
          .doc(entry.institutionId)
          .collection('procurement_stock_batches')
          .where('entryId', isEqualTo: entry.id)
          .where('itemId', isEqualTo: newItem.itemId)
          .where('size', isEqualTo: newItem.size)
          .where('color', isEqualTo: newItem.color)
          .get();

      for (var doc in batchesSnapshot.docs) {
        final batchData = StockBatch.fromMap(doc.id, doc.data());
        
        // Adjust remaining quantity (if possible)
        double newRemaining = batchData.remainingQuantity + qtyDelta;
        if (newRemaining < 0) newRemaining = 0; // Prevent negative stock

        batch.update(doc.reference, {
          'unitCost': newItem.costPrice ?? 0.0,
          'originalQuantity': newItem.quantity.toDouble(),
          'remainingQuantity': newRemaining,
          'createdAt': entry.intakeDate, // Update date if changed
        });
      }

      // Update general stock level
      final stockDocId = '${newItem.itemId}_${newItem.size}_${newItem.color}_${entry.warehouseId}';
      final stockRef = _db.collection('institutions').doc(entry.institutionId).collection('procurement_stock').doc(stockDocId);
      final stockDoc = await stockRef.get();
      if (stockDoc.exists) {
        final currentQty = (stockDoc.data()?['quantity'] ?? 0.0).toDouble();
        batch.update(stockRef, {'quantity': currentQty + qtyDelta});
      }
    }

    // 3. Propagate cost changes to orders to fix "profits not updating"
    // Search for all orders that might have used these items
    final ordersSnapshot = await _db.collection('institutions').doc(entry.institutionId).collection('procurement_orders')
        .where('status', whereIn: ['delivered', 'invoiced'])
        .get();

    for (var doc in ordersSnapshot.docs) {
      final order = ProcurementOrder.fromMap(doc.id, doc.data()!);
      bool orderUpdated = false;
      final List<OrderItemDetails> updatedItems = [];

      for (var orderItem in order.items) {
        final newItem = entry.items.where((i) => i.itemId == orderItem.itemId && i.size == orderItem.size && i.color == orderItem.color).firstOrNull;
        
        if (newItem != null) {
          // If this order item was fulfilled after the entry date, it's likely it used this batch
          // We update the costPrice. Note: This is an approximation for performance.
          // Ideally we'd track batch IDs in the order item.
          if (order.orderDate.isAfter(oldEntry.intakeDate) || order.orderDate.isAtSameMomentAs(oldEntry.intakeDate)) {
             updatedItems.add(OrderItemDetails(
               itemId: orderItem.itemId,
               itemName: orderItem.itemName,
               itemReference: orderItem.itemReference,
               size: orderItem.size,
               color: orderItem.color,
               quantity: orderItem.quantity,
               unitPrice: orderItem.unitPrice,
               costPrice: newItem.costPrice, // Propagate the new cost price
             ));
             orderUpdated = true;
             continue;
          }
        }
        updatedItems.add(orderItem);
      }

      if (orderUpdated) {
        batch.update(doc.reference, {'items': updatedItems.map((e) => e.toMap()).toList()});
      }
    }

    // Get a reference string for the log
    String logReference = entry.id;
    if (entry.items.isNotEmpty) {
      logReference = entry.items.first.itemReference ?? entry.id;
    }

    final log = InventoryAuditLog(
      id: const Uuid().v4(),
      institutionId: entry.institutionId,
      itemId: entry.items.length == 1 ? entry.items.first.itemId : 'multiple',
      itemName: entry.items.length == 1 ? entry.items.first.itemName : 'Edição de Entrada',
      size: entry.items.length == 1 ? entry.items.first.size : 'N/A',
      userId: performer.id,
      userName: performer.name,
      action: InventoryAction.adjustment,
      quantityChanged: 0,
      resultingStock: 0,
      timestamp: DateTime.now(),
      referenceId: logReference,
      notes: 'Edição completa de entrada (Qtd/Preço/Data) na fatura: ${entry.invoiceNumber}',
    );
    _logMovement(batch, log);

    await batch.commit();
  }

  void _logMovement(WriteBatch batch, InventoryAuditLog log) {
    final ref = _db
        .collection('institutions')
        .doc(log.institutionId)
        .collection('procurement_audit')
        .doc(log.id);
    batch.set(ref, log.toMap());
  }

  // --- Orders & Fulfillment ---

  Future<void> placeOrder(ProcurementOrder order) async {
    // Check if any item is discontinued
    for (var item in order.items) {
      final itemDoc = await _db.collection('institutions').doc(order.institutionId).collection('procurement_items').doc(item.itemId).get();
      if (itemDoc.exists && (itemDoc.data()?['isDiscontinued'] ?? false)) {
        throw Exception('O artigo "${item.itemName}" está descontinuado e não pode ser encomendado.');
      }
    }

    await _checkInventoryLock(order.institutionId, order.orderDate);
    await _db
        .collection('institutions')
        .doc(order.institutionId)
        .collection('procurement_orders')
        .doc(order.id)
        .set({
          ...order.toMap(),
          'itemIds': order.items.map((e) => e.itemId).toList(),
        });
        
    await _notifications.sendNotification(
      userId: order.institutionId,
      title: 'Nova Encomenda!',
      body: '${order.customerName} encomendou ${order.items.length} artigos.',
      data: {'type': 'new_order', 'orderId': order.id},
    );
  }

  Future<void> fulfillOrder(String institutionId, String orderId, String warehouseId, UserModel performer, {String? invoiceNumber, String? invoiceNotes, double? invoiceAmount}) async {
    final orderDoc = await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_orders')
        .doc(orderId)
        .get();
        
    if (!orderDoc.exists) return;
    final order = ProcurementOrder.fromMap(orderDoc.id, orderDoc.data()!);
    if (order.status == OrderStatus.delivered) return;

    await _checkInventoryLock(institutionId, DateTime.now());

    // Check if any item is discontinued
    for (var item in order.items) {
      final itemDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(item.itemId).get();
      if (itemDoc.exists && (itemDoc.data()?['isDiscontinued'] ?? false)) {
        throw Exception('Não é possível satisfazer esta encomenda: o artigo "${item.itemName}" foi descontinuado.');
      }
    }

    final batch = _db.batch();
    final List<OrderItemDetails> updatedItems = List.from(order.items);
    
    for (int i = 0; i < order.items.length; i++) {
      final itemDetails = order.items[i];
      final stockDocId = '${itemDetails.itemId}_${itemDetails.size}_${itemDetails.color}_$warehouseId';
      final stockRef = _db
          .collection('institutions')
          .doc(institutionId)
          .collection('procurement_stock')
          .doc(stockDocId);
          
      final stockDoc = await stockRef.get();
      final currentQty = (stockDoc.data()?['quantity'] ?? 0.0).toDouble();
      final newQty = currentQty - itemDetails.quantity;

      // FIFO Logic: Consume batches
      final batchesQuery = await _db.collection('institutions')
          .doc(institutionId)
          .collection('procurement_stock_batches')
          .where('itemId', isEqualTo: itemDetails.itemId)
          .where('size', isEqualTo: itemDetails.size)
          .where('color', isEqualTo: itemDetails.color)
          .where('warehouseId', isEqualTo: warehouseId)
          .where('remainingQuantity', isGreaterThan: 0)
          .get();
          
      final batches = batchesQuery.docs.map((d) => StockBatch.fromMap(d.id, d.data())).toList();
      batches.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO Sort

      double needed = itemDetails.quantity.toDouble();
      double totalCostForThisItem = 0.0;

      for (var batchItem in batches) {
        if (needed <= 0) break;
        double toConsume = batchItem.remainingQuantity > needed ? needed : batchItem.remainingQuantity;
        totalCostForThisItem += toConsume * batchItem.unitCost;
        needed -= toConsume;
        
        batch.update(_db.collection('institutions').doc(institutionId).collection('procurement_stock_batches').doc(batchItem.id), {
          'remainingQuantity': batchItem.remainingQuantity - toConsume,
        });
      }

      // Record the actual unit cost for this sale in the order item
      final actualUnitCost = itemDetails.quantity > 0 ? totalCostForThisItem / itemDetails.quantity : 0.0;
      updatedItems[i] = OrderItemDetails(
        itemId: itemDetails.itemId,
        itemName: itemDetails.itemName,
        itemReference: itemDetails.itemReference,
        size: itemDetails.size,
        color: itemDetails.color,
        quantity: itemDetails.quantity,
        unitPrice: itemDetails.unitPrice,
        costPrice: actualUnitCost,
      );

      batch.set(stockRef, {'quantity': newQty}, SetOptions(merge: true));

      final log = InventoryAuditLog(
        id: const Uuid().v4(),
        institutionId: institutionId,
        itemId: itemDetails.itemId,
        itemName: itemDetails.itemName,
        size: itemDetails.size,
        color: itemDetails.color,
        warehouseId: warehouseId,
        userId: performer.id,
        userName: performer.name,
        action: InventoryAction.sale,
        quantityChanged: -itemDetails.quantity.toDouble(),
        resultingStock: newQty,
        timestamp: DateTime.now(),
        referenceId: itemDetails.itemReference ?? orderId,
        notes: 'Venda a ${order.customerName} (Satisfeita)',
      );
      _logMovement(batch, log);
    }

    batch.update(orderDoc.reference, {
      'status': OrderStatus.delivered.name,
      'performedById': performer.id,
      'performedByName': performer.name,
      'items': updatedItems.map((e) => e.toMap()).toList(),
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (invoiceNotes != null) 'invoiceNotes': invoiceNotes,
      if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
    });
    
    // Archival for audit compliance
    try {
      final institutionDoc = await _db.collection('institutions').doc(institutionId).get();
      final institutionName = institutionDoc.data()?['name'] ?? 'Instituição';
      
      final pdfDoc = _buildDeliveryNotePdf(order, institutionName);
      final pdfBytes = await pdfDoc.save();
      final invoiceUrl = await _archiveInvoice(institutionId, orderId, pdfBytes);
      
      batch.update(orderDoc.reference, {'invoiceUrl': invoiceUrl});
    } catch (e) {
      debugPrint('Error archiving delivery note: $e');
    }

    await batch.commit();
    
    // Notify customer
    await _notifications.sendNotification(
      userId: order.customerId,
      title: 'Encomenda Entregue!',
      body: 'A sua encomenda #${order.id.substring(0,8)} foi entregue/satisfeita.',
      data: {'type': 'order_fulfilled', 'orderId': order.id},
    );
  }

  Future<void> invoiceOrder(String institutionId, String orderId, UserModel performer, {required String invoiceNumber, double? invoiceAmount, String? invoiceNotes}) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_orders')
        .doc(orderId)
        .update({
          'status': OrderStatus.invoiced.name,
          'invoiceNumber': invoiceNumber,
          if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
          if (invoiceNotes != null) 'invoiceNotes': invoiceNotes,
          'invoicedById': performer.id,
          'invoicedByName': performer.name,
          'invoicedAt': FieldValue.serverTimestamp(),
        });

    final orderDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_orders').doc(orderId).get();
    final order = ProcurementOrder.fromMap(orderDoc.id, orderDoc.data()!);
    
    // Notify customer
    await _notifications.sendNotification(
      userId: order.customerId,
      title: 'Encomenda Faturada',
      body: 'A fatura #${invoiceNumber} da sua encomenda foi emitida.',
      data: {'type': 'order_invoiced', 'orderId': orderId},
    );
  }

  Future<void> updateOrderInvoice(String institutionId, String orderId, {String? invoiceNumber, String? invoiceNotes, double? invoiceAmount}) async {
    await _db
        .collection('institutions')
        .doc(institutionId)
        .collection('procurement_orders')
        .doc(orderId)
        .update({
          if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
          if (invoiceNotes != null) 'invoiceNotes': invoiceNotes,
          if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
        });
  }

  // --- Invoicing ---

  pw.Document _buildInvoiceDocument(ProcurementOrder order, String institutionName) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('GUIA DE ENTREGA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Cliente: ${order.customerName}'),
                      pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(order.orderDate)}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Encomenda: #${order.id.substring(0, 8).toUpperCase()}'),
                      pw.Text('Estado: ${order.status.name.toUpperCase()}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Artigo', 'Tam/Cor', 'Qtd', 'Preço Un.', 'Total'],
                data: order.items.map((item) => [
                  item.itemName,
                  '${item.size} / ${item.color}',
                  item.quantity.toString(),
                  '€ ${item.unitPrice.toStringAsFixed(2)}',
                  '€ ${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total: € ${order.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Documento processado por computador.', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text('Gerado por EduGaming Aprovisionamento 360', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> generateInvoicePdf(ProcurementOrder order, String institutionName) async {
    final pdf = _buildInvoiceDocument(order, institutionName);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Factura_${order.id.substring(0,8)}.pdf');
  }

  Future<void> generateDeliveryNotePdf(ProcurementOrder order, String institutionName) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('GUIA DE REMESSA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('Destinatário: ${order.customerName}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Data de Entrega: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Artigo', 'Variante', 'Quantidade'],
                data: order.items.map((item) => [
                  item.itemName,
                  '${item.size} / ${item.color}',
                  item.quantity.toString(),
                ]).toList(),
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.SizedBox(width: 150, child: pw.Divider()), 
                    pw.Text('Assinatura Instituição', style: const pw.TextStyle(fontSize: 10))
                  ]),
                  pw.Column(children: [
                    pw.SizedBox(width: 150, child: pw.Divider()), 
                    pw.Text('Assinatura Cliente', style: const pw.TextStyle(fontSize: 10))
                  ]),
                ],
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text('Documento de acompanhamento de mercadoria - ERP EduGaming', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'GuiaRemessa_${order.id.substring(0,8)}.pdf');
  }

  pw.Document _buildDeliveryNotePdf(ProcurementOrder order, String institutionName) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(institutionName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('GUIA DE REMESSA / ENTREGA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('Destinatário: ${order.customerName}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Data de Entrega: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
              pw.Text('Encomenda: #${order.id.substring(0, 8).toUpperCase()}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Artigo', 'Variante', 'Quantidade'],
                data: order.items.map((item) => [
                  item.itemName,
                  '${item.size} / ${item.color}',
                  item.quantity.toString(),
                ]).toList(),
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.SizedBox(width: 150, child: pw.Divider()), 
                    pw.Text('Assinatura Instituição', style: const pw.TextStyle(fontSize: 10))
                  ]),
                  pw.Column(children: [
                    pw.SizedBox(width: 150, child: pw.Divider()), 
                    pw.Text('Assinatura Cliente', style: const pw.TextStyle(fontSize: 10))
                  ]),
                ],
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text('Documento de acompanhamento de mercadoria - ERP EduGaming', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<double> getInventoryRevenueForPeriod(String institutionId, DateTime start, DateTime end) async {
    // Simplified query to avoid index issues. Get all and filter locally.
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_orders')
        .get();
        
    double total = 0.0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final status = data['status'];
      final date = (data['orderDate'] as Timestamp?)?.toDate();
      
      if (['delivered', 'invoiced'].contains(status) && 
          date != null && date.isAfter(start.subtract(const Duration(seconds: 1))) && 
          date.isBefore(end.add(const Duration(seconds: 1)))) {
        total += (data['totalAmount'] ?? 0.0).toDouble();
      }
    }
    return total;
  }

  Future<double> getInventoryProfitForPeriod(String institutionId, DateTime start, DateTime end) async {
    final revenue = await getInventoryRevenueForPeriod(institutionId, start, end);
    final cost = await getInventoryCostForPeriod(institutionId, start, end);
    final regularizationValue = await getInventoryRegularizationValueForPeriod(institutionId, start, end);
    return revenue - cost + regularizationValue;
  }

  Future<double> getInventoryRegularizationValueForPeriod(String institutionId, DateTime start, DateTime end) async {
    // Simplified query to avoid index issues. Get all and filter locally.
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_audit')
        .get();
        
    double totalRegularizationValue = 0.0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final action = data['action'];
      final date = (data['timestamp'] as Timestamp?)?.toDate();
      
      if (action == InventoryAction.regularization.name && 
          date != null && 
          date.isAfter(start.subtract(const Duration(seconds: 1))) && 
          date.isBefore(end.add(const Duration(seconds: 1)))) {
        
        final qtyChanged = (data['quantityChanged'] ?? 0.0).toDouble();
        
        // We need the cost at the time. The audit log doesn't store it yet.
        // Let's use the current cost price as a fallback, or better, 
        // in finalizeRegularization we should have stored it in the audit log notes or a new field.
        // Actually, we can fetch it from the item if we don't have it.
        final itemId = data['itemId'];
        final itemDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).get();
        final costPrice = (itemDoc.data()?['costPrice'] ?? 0.0).toDouble();
        
        // Negative qtyChanged (loss/theft) means positive COST (expense).
        // Positive qtyChanged (surplus) means negative COST (saving/revenue adjustment).
        // But in the financial report, we usually show adjustments as a separate line.
        totalRegularizationValue += qtyChanged * costPrice;
      }
    }
    return totalRegularizationValue;
  }

  Future<double> getTotalExpenseForPeriod(String institutionId, DateTime start, DateTime end) async {
    final snap = await _db.collection('institutions').doc(institutionId).collection('finance_transactions')
        .where('type', isEqualTo: TransactionType.expense.name)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    return snap.docs.fold<double>(0.0, (acc, doc) => acc + (doc.data()['amount'] ?? 0.0).toDouble());
  }

  Future<double> getInventoryCostForPeriod(String institutionId, DateTime start, DateTime end) async {
    // Simplified query to avoid index issues. Get all and filter locally.
    final snap = await _db.collection('institutions').doc(institutionId).collection('procurement_orders')
        .get();
        
    double totalCost = 0.0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final status = data['status'];
      final date = (data['orderDate'] as Timestamp?)?.toDate();

      if (['delivered', 'invoiced'].contains(status) && 
          date != null && date.isAfter(start.subtract(const Duration(seconds: 1))) && 
          date.isBefore(end.add(const Duration(seconds: 1)))) {
        final items = data['items'] as List? ?? [];
        for (var item in items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final cost = (item['costPrice'] ?? 0.0).toDouble();
          totalCost += qty * cost;
        }
      }
    }
    return totalCost;
  }

  Stream<List<InventoryRegularization>> getRegularizations(String institutionId) {
    // Use snapshots without orderBy to avoid index issues, then sort locally
    return _db.collection('institutions').doc(institutionId).collection('procurement_regularizations')
        .snapshots()
        .map((snapshot) {
          try {
            final regs = snapshot.docs.map((doc) => InventoryRegularization.fromMap(doc.id, doc.data())).toList();
            regs.sort((a, b) => b.date.compareTo(a.date));
            return regs;
          } catch (e) {
            debugPrint('Error mapping regularizations: $e');
            return []; // Return empty list instead of crashing stream
          }
        });
  }

  Future<void> saveRegularization(InventoryRegularization reg) async {
    await _db.collection('institutions').doc(reg.institutionId).collection('procurement_regularizations').doc(reg.id).set(reg.toMap());
  }

  Future<void> deleteRegularization(String institutionId, String regId) async {
    final regDoc = await _db.collection('institutions').doc(institutionId).collection('procurement_regularizations').doc(regId).get();
    if (!regDoc.exists) return;
    
    final reg = InventoryRegularization.fromMap(regDoc.id, regDoc.data()!);
    
    if (reg.status == 'finalized') {
      final batch = _db.batch();
      
      for (var item in reg.items) {
        final stockDocId = '${item.itemId}_${item.size}_${item.color}_${reg.warehouseId}';
        final stockRef = _db.collection('institutions').doc(institutionId).collection('procurement_stock').doc(stockDocId);
        
        final stockSnap = await stockRef.get();
        final currentQty = (stockSnap.data()?['quantity'] ?? 0.0).toDouble();
        
        final reverseQty = -item.quantity;
        final newQty = currentQty + reverseQty;

        batch.set(stockRef, {'quantity': newQty}, SetOptions(merge: true));

        if (item.quantity > 0) {
          // Addition was done -> Delete the batch created
          final batchSnap = await _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches')
              .where('entryId', isEqualTo: reg.id)
              .where('itemId', isEqualTo: item.itemId)
              .get();
          for (var b in batchSnap.docs) {
            batch.delete(b.reference);
          }
        } else if (item.quantity < 0) {
          // Subtraction was done -> Restore stock by creating a compensatory batch
          final batchRef = _db.collection('institutions').doc(institutionId).collection('procurement_stock_batches').doc();
          final stockBatch = StockBatch(
            id: batchRef.id,
            institutionId: institutionId,
            itemId: item.itemId,
            size: item.size,
            color: item.color,
            warehouseId: reg.warehouseId,
            originalQuantity: -item.quantity,
            remainingQuantity: -item.quantity,
            unitCost: item.unitCost,
            createdAt: DateTime.now(),
            entryId: 'ANNUL_${reg.id}',
          );
          batch.set(batchRef, stockBatch.toMap());
        }
        
        final auditLog = InventoryAuditLog(
          id: const Uuid().v4(),
          institutionId: institutionId,
          itemId: item.itemId,
          itemName: item.itemName,
          size: item.size,
          color: item.color,
          warehouseId: reg.warehouseId,
          userId: 'SYSTEM',
          userName: 'Anulação',
          action: InventoryAction.regularization,
          quantityChanged: reverseQty,
          resultingStock: newQty,
          timestamp: DateTime.now(),
          referenceId: reg.id,
          itemReference: item.itemReference,
          notes: 'Anulação de Regularização: ${reg.id.substring(0,8)}',
        );
        _logMovement(batch, auditLog);
      }
      await batch.commit();
    }
    
    await _db.collection('institutions').doc(institutionId).collection('procurement_regularizations').doc(regId).delete();
  }

  Future<void> finalizeRegularization(InventoryRegularization reg, UserModel performer) async {
    await _checkInventoryLock(reg.institutionId, reg.date);
    
    final batch = _db.batch();
    
    for (var item in reg.items) {
      final stockDocId = '${item.itemId}_${item.size}_${item.color}_${reg.warehouseId}';
      final stockRef = _db.collection('institutions').doc(reg.institutionId).collection('procurement_stock').doc(stockDocId);
      
      final stockDoc = await stockRef.get();
      final currentQty = (stockDoc.data()?['quantity'] ?? 0.0).toDouble();
      final newQty = currentQty + item.quantity;

      batch.set(stockRef, {
        'itemId': item.itemId,
        'size': item.size,
        'color': item.color,
        'warehouseId': reg.warehouseId,
        'quantity': newQty,
      }, SetOptions(merge: true));

      // FIFO Logic
      if (item.quantity > 0) {
        // Addition (Sobra/Entrada)
        final batchRef = _db.collection('institutions').doc(reg.institutionId).collection('procurement_stock_batches').doc();
        final stockBatch = StockBatch(
          id: batchRef.id,
          institutionId: reg.institutionId,
          itemId: item.itemId,
          size: item.size,
          color: item.color,
          warehouseId: reg.warehouseId,
          originalQuantity: item.quantity,
          remainingQuantity: item.quantity,
          unitCost: item.unitCost,
          createdAt: reg.date,
          entryId: reg.id,
        );
        batch.set(batchRef, stockBatch.toMap());
      } else if (item.quantity < 0) {
        // Subtraction (Quebra/Roubo)
        double qtyToConsume = -item.quantity;
        final batchesQuery = await _db.collection('institutions')
            .doc(reg.institutionId)
            .collection('procurement_stock_batches')
            .where('itemId', isEqualTo: item.itemId)
            .where('size', isEqualTo: item.size)
            .where('color', isEqualTo: item.color)
            .where('warehouseId', isEqualTo: reg.warehouseId)
            .get();

        // Sort locally to avoid composite index requirement
        final sortedDocs = batchesQuery.docs.toList()
          ..sort((a, b) {
            final aDate = (a.data()['createdAt'] ?? a.data()['date'] ?? Timestamp.now()) as Timestamp;
            final bDate = (b.data()['createdAt'] ?? b.data()['date'] ?? Timestamp.now()) as Timestamp;
            return aDate.compareTo(bDate);
          });

        for (var doc in sortedDocs) {
          if (qtyToConsume <= 0) break;
          final batchData = StockBatch.fromMap(doc.id, doc.data());
          if (batchData.remainingQuantity <= 0) continue; // Filter locally to avoid range index requirement
          
          final double consumed = (batchData.remainingQuantity >= qtyToConsume) ? qtyToConsume : batchData.remainingQuantity;
          batch.update(doc.reference, {'remainingQuantity': batchData.remainingQuantity - consumed});
          qtyToConsume -= consumed;
        }
      }

      final auditLog = InventoryAuditLog(
        id: const Uuid().v4(),
        institutionId: reg.institutionId,
        itemId: item.itemId,
        itemName: item.itemName,
        size: item.size,
        color: item.color,
        warehouseId: reg.warehouseId,
        userId: performer.id,
        userName: performer.name,
        action: InventoryAction.regularization,
        quantityChanged: item.quantity,
        resultingStock: newQty,
        timestamp: DateTime.now(),
        referenceId: reg.id,
        itemReference: item.itemReference,
        notes: 'Regularização Formal (${reg.reason}): ${reg.id.substring(0,8)}',
      );
      _logMovement(batch, auditLog);
    }

    // 4. Update regularization status and save FULL document if it's new
    batch.set(_db.collection('institutions').doc(reg.institutionId).collection('procurement_regularizations').doc(reg.id), {
      ...reg.toMap(),
      'status': 'finalized',
      'performedById': performer.id,
      'performedByName': performer.name,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> generateRegularizationPdf(String institutionName, InventoryRegularization reg) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('Documento de Regularização de Inventário - $institutionName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
          pw.SizedBox(height: 10),
          pw.Text('Nº Regularização: ${reg.id.substring(0,8).toUpperCase()}'),
          pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(reg.date)}'),
          pw.Text('Motivo: ${reg.reason}'),
          pw.Text('Estado: ${reg.status.toUpperCase()}'),
          pw.SizedBox(height: 24),
          pw.TableHelper.fromTextArray(
            headers: ['Artigo', 'Ref', 'Variante', 'Qtd', 'Custo Unit.', 'Total'],
            data: [
              ...reg.items.map((i) => [
                i.itemName,
                i.itemReference ?? '-',
                '${i.size} / ${i.color}',
                i.quantity.toInt().toString(),
                '${i.unitCost.toStringAsFixed(2)} EUR',
                '${(i.quantity * i.unitCost).abs().toStringAsFixed(2)} EUR',
              ]),
              [
                'TOTAL',
                '',
                '',
                '',
                '',
                '${reg.items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitCost).abs()).toStringAsFixed(2)} EUR',
              ]
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Assinatura do Utilizador: ${reg.performedByName ?? ""}', style: const pw.TextStyle(fontSize: 8))]),
              pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Data e Carimbo Institucional', style: const pw.TextStyle(fontSize: 8))]),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Regularizacao_${reg.id.substring(0,8)}.pdf');
  }

  Future<double> getAverageCost(String institutionId, String itemId, String size, String color, String warehouseId) async {
    // Simplified query to avoid index issues. Get batches and sort locally.
    final batches = await _db.collection('institutions')
        .doc(institutionId)
        .collection('procurement_stock_batches')
        .where('itemId', isEqualTo: itemId)
        .where('size', isEqualTo: size)
        .where('color', isEqualTo: color)
        .where('warehouseId', isEqualTo: warehouseId)
        .get();
    
    if (batches.docs.isEmpty) {
      final item = await _db.collection('institutions').doc(institutionId).collection('procurement_items').doc(itemId).get();
      return (item.data()?['costPrice'] ?? 0.0).toDouble();
    }
    
    // Sort locally to get the latest (descending)
    final sortedDocs = batches.docs.toList()
      ..sort((a, b) {
        final aDate = (a.data()['createdAt'] ?? a.data()['date'] ?? Timestamp.now()) as Timestamp;
        final bDate = (b.data()['createdAt'] ?? b.data()['date'] ?? Timestamp.now()) as Timestamp;
        return bDate.compareTo(aDate);
      });
    
    return (sortedDocs.first.data()['unitCost'] ?? 0.0).toDouble();
  }

  Future<void> generateStockReportPdf({
    required String institutionId,
    required String institutionName,
    String? warehouseId,
    bool showTotalWithWarehouses = false,
  }) async {
    final pdf = pw.Document();
    final itemsSnap = await _db.collection('institutions').doc(institutionId).collection('procurement_items').get();
    final items = itemsSnap.docs.map((d) => ProcurementItem.fromMap(d.id, d.data())).toList();
    
    final stockSnap = await _db.collection('institutions').doc(institutionId).collection('procurement_stock').get();
    final allStocks = stockSnap.docs.map((d) => ProcurementStock.fromMap(d.id, d.data())).toList();

    final warehousesSnap = await _db.collection('institutions').doc(institutionId).collection('procurement_warehouses').get();
    final warehouses = warehousesSnap.docs.map((d) => Warehouse.fromMap(d.id, d.data())).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('Relatório de Existências - $institutionName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
          pw.SizedBox(height: 10),
          pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
          if (warehouseId != null) pw.Text('Armazém: ${warehouses.firstWhere((w) => w.id == warehouseId).name}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Artigo', 'Ref', 'Variante', 'Qtd', if (showTotalWithWarehouses) 'Detalhe Armazéns'],
            data: items.expand((item) {
              final itemStocks = allStocks.where((s) => s.itemId == item.id && (warehouseId == null || s.warehouseId == warehouseId)).toList();
              
              Map<String, double> variants = {};
              Map<String, Map<String, double>> variantsByWarehouse = {};

              for (var s in itemStocks) {
                final key = '${s.size}_${s.color}';
                variants[key] = (variants[key] ?? 0) + s.quantity;
                variantsByWarehouse.putIfAbsent(key, () => {});
                variantsByWarehouse[key]![s.warehouseId] = s.quantity;
              }

              return variants.entries.map((v) {
                String warehouseDetail = '';
                if (showTotalWithWarehouses) {
                   warehouseDetail = variantsByWarehouse[v.key]!.entries.map((e) {
                     final wName = warehouses.firstWhere((w) => w.id == e.key, orElse: () => Warehouse(id: '', institutionId: '', name: 'Desconhecido')).name;
                     return '$wName: ${e.value.toInt()}';
                   }).join(', ');
                }

                return [
                  item.name,
                  item.reference,
                  v.key.replaceAll('_', ' / '),
                  v.value.toInt().toString(),
                  if (showTotalWithWarehouses) warehouseDetail,
                ];
              });
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'RelatorioStock.pdf');
  }

  Future<void> generateClosingReportPdf(String institutionName, InventoryClosing closing) async {
    final pdf = pw.Document();
    
    final itemsSnap = await _db.collection('institutions').doc(closing.institutionId).collection('procurement_items').get();
    final items = itemsSnap.docs.map((d) => ProcurementItem.fromMap(d.id, d.data())).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('Inventário de Fecho - $institutionName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
          pw.SizedBox(height: 10),
          pw.Text('Data do Fecho: ${DateFormat('dd/MM/yyyy').format(closing.closingDate)}'),
          pw.Text('Responsável Contagem: ${closing.counterName}'),
          pw.Text('Responsável Aprovação: ${closing.approverName}'),
          pw.SizedBox(height: 30),
          pw.TableHelper.fromTextArray(
            headers: ['Artigo', 'Referência', 'Tamanho', 'Cor', 'Quantidade'],
            data: closing.stockSnapshot.entries.map((e) {
              final parts = e.key.split('_');
              final item = items.firstWhere((i) => i.id == parts[0], orElse: () => ProcurementItem(id: '', institutionId: '', name: 'Desconhecido', price: 0));
              return [
                item.name,
                item.reference,
                parts[1],
                parts[2],
                e.value.toInt().toString(),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Assinatura Responsável Contagem', style: const pw.TextStyle(fontSize: 8))]),
              pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Assinatura Responsável Aprovação', style: const pw.TextStyle(fontSize: 8))]),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'InventarioFecho_${DateFormat('yyyy').format(closing.closingDate)}.pdf');
  }
}
