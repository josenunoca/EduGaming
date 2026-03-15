import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/internal_message.dart';

class MessagingBadge extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const MessagingBadge({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final userId = service.currentUser?.uid ?? '';

    if (userId.isEmpty) return IconButton(icon: icon, onPressed: onPressed);

    return StreamBuilder<List<InternalMessage>>(
      stream: service.getInboxStream(userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData
            ? snapshot.data!.where((m) => !m.readBy.contains(userId)).length
            : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: icon,
              onPressed: onPressed,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
