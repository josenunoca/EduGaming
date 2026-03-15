import 'package:flutter/material.dart';
import '../../models/internal_message.dart';
import '../../widgets/ai_translated_text.dart';
import 'compose_message_screen.dart';

class MessageDetailScreen extends StatelessWidget {
  final InternalMessage message;

  const MessageDetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AiTranslatedText('Message Details'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.subject,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white24, height: 32),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF7B61FF),
                            child: Text(
                                message.senderName
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.senderName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16)),
                              Text(_formatDate(message.timestamp),
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const AiTranslatedText('Para:',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(
                        '${message.recipientIds.length} destinatários',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  message.body,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reply_all',
            onPressed: () => _handleReply(context, replyAll: true),
            icon: const Icon(Icons.reply_all),
            label: const AiTranslatedText('Responder a Todos'),
            backgroundColor: const Color(0xFF00D1FF),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'reply',
            onPressed: () => _handleReply(context, replyAll: false),
            icon: const Icon(Icons.reply),
            label: const AiTranslatedText('Responder'),
            backgroundColor: const Color(0xFF7B61FF),
          ),
        ],
      ),
    );
  }

  void _handleReply(BuildContext context, {required bool replyAll}) {
    List<String> toIds = [message.senderId];
    List<String> ccIds = [];

    if (replyAll) {
      // Add other recipients and CCs to CC list
      ccIds.addAll(message.recipientIds);
      ccIds.addAll(message.ccIds);

      // Filter out original sender (who is now in 'To') and current user
      // Note: We don't have current user ID easily here without a provider,
      // but ComposeMessageScreen handles the 'To' list.
      // Let's just pass them and let compose screen or a wrapper handle it.
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeMessageScreen(
          initialRecipientIds: toIds,
          initialCcIds: ccIds.isNotEmpty ? ccIds : null,
          initialSubject: message.subject.startsWith('Re:')
              ? message.subject
              : 'Re: ${message.subject}',
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
