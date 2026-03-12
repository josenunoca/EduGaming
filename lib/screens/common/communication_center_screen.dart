import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/internal_message.dart';
import '../../widgets/ai_translated_text.dart';
import 'compose_message_screen.dart';
import 'message_detail_screen.dart';

class CommunicationCenterScreen extends StatefulWidget {
  final String? forUserId;
  const CommunicationCenterScreen({super.key, this.forUserId});

  @override
  State<CommunicationCenterScreen> createState() => _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends State<CommunicationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final currentUserId = service.currentUser?.uid ?? '';
    final targetUserId = widget.forUserId ?? currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: AiTranslatedText(widget.forUserId != null && widget.forUserId != currentUserId 
            ? 'Messages for Child' : 'Communication Center'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(child: AiTranslatedText('Inbox')),
            Tab(child: AiTranslatedText('Sent')),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _MessageList(stream: service.getInboxStream(targetUserId), isInbox: true),
            _MessageList(stream: service.getSentMessagesStream(targetUserId), isInbox: false),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComposeMessageScreen()),
        ),
        icon: const Icon(Icons.edit),
        label: const AiTranslatedText('Compose'),
        backgroundColor: const Color(0xFF7B61FF),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final Stream<List<InternalMessage>> stream;
  final bool isInbox;

  const _MessageList({required this.stream, required this.isInbox});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final userId = service.currentUser?.uid ?? '';

    return StreamBuilder<List<InternalMessage>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                const AiTranslatedText('No messages found', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        final messages = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isRead = msg.readBy.contains(userId);

            return Card(
              color: isRead ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isRead ? Colors.transparent : const Color(0xFF7B61FF).withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: ListTile(
                onTap: () {
                  if (!isRead && isInbox) {
                    service.markMessageRead(userId, msg.id);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MessageDetailScreen(message: msg)),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey[800] : const Color(0xFF7B61FF),
                  child: Text(msg.senderName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(
                  msg.subject,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${isInbox ? 'From: ${msg.senderName}' : 'To: ${msg.recipientIds.length} recipients'}\n${_formatDate(msg.timestamp)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: !isRead && isInbox 
                  ? const Icon(Icons.circle, color: Color(0xFF7B61FF), size: 12)
                  : null,
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
