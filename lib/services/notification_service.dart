import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/internal_message.dart';
import '../models/procurement/procurement_models.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Send a notification to specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // 1. Internal Message
    final msg = InternalMessage(
      id: const Uuid().v4(),
      senderId: 'SYSTEM',
      senderName: 'EduGaming System',
      recipientIds: [userId],
      subject: title,
      body: body,
      timestamp: DateTime.now(),
    );
    await _db.collection('messages').doc(msg.id).set(msg.toMap());

    // 2. Push Notification (FCM Placeholder)
    final userDoc = await _db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final user = UserModel.fromMap(userDoc.data()!);
      if (user.pushToken != null) {
        _sendFCM(user.pushToken!, title, body, data);
      }
      
      // 3. SMS/WhatsApp (Placeholder)
      if (user.whatsappNumber != null) {
        _sendWhatsApp(user.whatsappNumber!, '$title: $body');
      }
    }
  }

  /// Targetted Low Stock Notification
  Future<void> notifyLowStock(String institutionId, ProcurementItem item, String size, double currentStock) async {
    // Find managers delegated for 'procurement'
    final instDoc = await _db.collection('institutions').doc(institutionId).get();
    if (!instDoc.exists) return;
    
    final delegated = instDoc.data()?['delegatedRoles']?['procurement'] as List? ?? [];
    
    // Also notify main institution account if it's a user
    final targets = {...delegated, institutionId};

    for (var targetId in targets) {
      await sendNotification(
        userId: targetId,
        title: '⚠️ ALERTA DE STOCK: ${item.name}',
        body: 'O stock do tamanho $size atingiu ${currentStock.toInt()} unidades (Mínimo: ${item.minSafetyStock.toInt()}). Sugerimos repor stock.',
        data: {'type': 'low_stock', 'itemId': item.id, 'size': size},
      );
    }
  }

  void _sendFCM(String token, String title, String body, Map<String, dynamic>? data) {
    debugPrint('FCM PUSH SENT TO $token: $title - $body');
    // Integration with cloud functions would happen here
  }

  void _sendWhatsApp(String number, String message) {
    debugPrint('WHATSAPP/SMS SENT TO $number: $message');
    // Integration with Twilio/WhatsApp API or uri_launcher
  }
}
