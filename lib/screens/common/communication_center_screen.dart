import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/firebase_service.dart';
import '../../models/internal_message.dart';
import '../../widgets/ai_translated_text.dart';
import 'compose_message_screen.dart';
import 'message_detail_screen.dart';

class CommunicationCenterScreen extends StatefulWidget {
  final String? forUserId;
  const CommunicationCenterScreen({super.key, this.forUserId});

  @override
  State<CommunicationCenterScreen> createState() =>
      _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends State<CommunicationCenterScreen> {
  String _activeFolder = 'inbox'; // 'inbox', 'sent', 'archive'
  String? _selectedThemeFilter; // Null if no theme filter is active
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Helper method to get theme colors dynamically
  Color _getThemeColor(String theme) {
    final clean = theme.trim().toLowerCase();
    switch (clean) {
      case 'urgente':
      case 'urgent':
      case 'importante':
        return const Color(0xFFFF4A4A); // Neon Red
      case 'trabalho':
      case 'work':
      case 'profissional':
        return const Color(0xFF00D1FF); // Neon Cyan
      case 'financeiro':
      case 'finanças':
      case 'pagamentos':
      case 'finance':
        return const Color(0xFF00FF87); // Mint Green
      case 'académico':
      case 'academics':
      case 'escola':
      case 'estudos':
        return const Color(0xFF7B61FF); // Royal Purple
      case 'pessoal':
      case 'personal':
        return const Color(0xFFFFA800); // Amber Orange
      default:
        final hash = clean.hashCode;
        final colors = [
          const Color(0xFF7B61FF),
          const Color(0xFF00D1FF),
          const Color(0xFF00FF87),
          const Color(0xFFFFA800),
          const Color(0xFFFF4A4A),
          const Color(0xFFF565C0),
          const Color(0xFF00FA9A),
          const Color(0xFF1E90FF),
          const Color(0xFFFFD700),
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  // Combine Inbox & Sent streams to have a fully unified real-time email list
  Stream<List<InternalMessage>> _getUnifiedMessagesStream(
      FirebaseService service, String userId) {
    return Rx.combineLatest2<List<InternalMessage>, List<InternalMessage>,
        List<InternalMessage>>(
      service.getInboxStream(userId),
      service.getSentMessagesStream(userId),
      (inbox, sent) {
        final all = <InternalMessage>[...inbox, ...sent];
        final uniqueIds = <String>{};
        final uniqueList = <InternalMessage>[];
        for (var msg in all) {
          if (uniqueIds.add(msg.id)) {
            uniqueList.add(msg);
          }
        }
        return uniqueList..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      },
    );
  }

  void _openThemeSelector(
      BuildContext context, FirebaseService service, String userId, InternalMessage message) {
    final TextEditingController customThemeController = TextEditingController();
    final currentTheme = message.userThemes[userId];

    final presetThemes = [
      'Urgente',
      'Trabalho',
      'Financeiro',
      'Académico',
      'Pessoal'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Classificar por Tema',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (currentTheme != null)
                    TextButton.icon(
                      icon: const Icon(Icons.label_off, color: Colors.white38, size: 16),
                      label: const AiTranslatedText('Remover Tema', style: TextStyle(color: Colors.white38)),
                      onPressed: () {
                        service.assignThemeToMessage(userId, message.id, null);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: AiTranslatedText('Tema removido da mensagem')),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Temas Predefinidos',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetThemes.map((theme) {
                  final isSelected = currentTheme == theme;
                  final themeColor = _getThemeColor(theme);
                  return FilterChip(
                    label: Text(theme),
                    selected: isSelected,
                    selectedColor: themeColor.withValues(alpha: 0.25),
                    checkmarkColor: themeColor,
                    labelStyle: TextStyle(
                      color: isSelected ? themeColor : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? themeColor : Colors.white10,
                        width: 1.5,
                      ),
                    ),
                    onSelected: (bool selected) {
                      service.assignThemeToMessage(userId, message.id, selected ? theme : null);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Mensagem classificada como "$theme"'),
                          backgroundColor: themeColor.withValues(alpha: 0.8),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Criar Novo Tema Customizado',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customThemeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ex: Projeto X, Família, Reuniões...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          service.assignThemeToMessage(userId, message.id, val.trim());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Novo tema "$val" criado e aplicado!'),
                              backgroundColor: _getThemeColor(val),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final val = customThemeController.text.trim();
                      if (val.isNotEmpty) {
                        service.assignThemeToMessage(userId, message.id, val);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Novo tema "$val" criado e aplicado!'),
                            backgroundColor: _getThemeColor(val),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B61FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final currentUserId = service.currentUser?.uid ?? '';
    final targetUserId = widget.forUserId ?? currentUserId;

    return StreamBuilder<List<InternalMessage>>(
      stream: _getUnifiedMessagesStream(service, targetUserId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];

        // Dynamically compute the set of unique themes the user has created/assigned
        final userThemes = <String>{};
        for (var msg in messages) {
          final theme = msg.userThemes[targetUserId];
          if (theme != null && theme.trim().isNotEmpty) {
            userThemes.add(theme.trim());
          }
        }

        // Calculate counts for badges
        final inboxUnreadCount = messages.where((msg) {
          final isInbox = msg.recipientIds.contains(targetUserId) || msg.ccIds.contains(targetUserId);
          final isArchived = msg.archivedBy.contains(targetUserId);
          final isRead = msg.readBy.contains(targetUserId);
          return isInbox && !isArchived && !isRead;
        }).length;

        // Apply filters
        var filteredMessages = messages.where((msg) {
          // 1. Search Query filter (match subject, body, senderName or category/theme)
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matchesSearch = msg.subject.toLowerCase().contains(query) ||
                msg.body.toLowerCase().contains(query) ||
                msg.senderName.toLowerCase().contains(query) ||
                (msg.userThemes[targetUserId]?.toLowerCase().contains(query) ?? false);
            if (!matchesSearch) return false;
          }

          // 2. Theme Filter overrides standard folder logic if active
          if (_selectedThemeFilter != null) {
            return msg.userThemes[targetUserId] == _selectedThemeFilter &&
                !msg.deletedBy.contains(targetUserId);
          }

          // 3. Standard Folder Filtering
          final isArchived = msg.archivedBy.contains(targetUserId);
          if (_activeFolder == 'archive') {
            return isArchived;
          } else {
            // Non-archived flow
            if (isArchived) return false;

            if (_activeFolder == 'inbox') {
              // Received messages
              return msg.recipientIds.contains(targetUserId) ||
                  msg.ccIds.contains(targetUserId);
            } else if (_activeFolder == 'sent') {
              // Sent messages
              return msg.senderId == targetUserId;
            }
          }
          return true;
        }).toList();

        final screenWidth = MediaQuery.of(context).size.width;
        final isWideScreen = screenWidth > 800;

        Widget mainList = _buildMessageList(
          context: context,
          messages: filteredMessages,
          service: service,
          userId: targetUserId,
          isLoading: snapshot.connectionState == ConnectionState.waiting,
        );

        Widget sidebar = _buildSidebar(
          context: context,
          themes: userThemes.toList(),
          inboxUnread: inboxUnreadCount,
          isDrawer: false,
        );

        return Scaffold(
          appBar: AppBar(
            title: AiTranslatedText(
              widget.forUserId != null && widget.forUserId != currentUserId
                  ? 'Mensagens do Educando'
                  : 'Centro de Correio e Mensagens',
            ),
            actions: [
              if (_selectedThemeFilter != null || _searchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar Filtros',
                  icon: const Icon(Icons.filter_alt_off, color: Color(0xFF00D1FF)),
                  onPressed: () {
                    setState(() {
                      _selectedThemeFilter = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
            ],
          ),
          drawer: !isWideScreen
              ? Drawer(
                  backgroundColor: const Color(0xFF0F172A),
                  child: SafeArea(
                    child: _buildSidebar(
                      context: context,
                      themes: userThemes.toList(),
                      inboxUnread: inboxUnreadCount,
                      isDrawer: true,
                    ),
                  ),
                )
              : null,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: Row(
              children: [
                if (isWideScreen) sidebar,
                Expanded(
                  child: Column(
                    children: [
                      // Elegant Search and active filter banner
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Pesquise por assunto, remetente ou tema...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white54),
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                            _searchController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                            ),
                            if (_selectedThemeFilter != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _getThemeColor(_selectedThemeFilter!).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getThemeColor(_selectedThemeFilter!).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.label, color: _getThemeColor(_selectedThemeFilter!)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'A filtrar pelo Tema: $_selectedThemeFilter',
                                        style: TextStyle(
                                          color: _getThemeColor(_selectedThemeFilter!),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _selectedThemeFilter = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(child: mainList),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComposeMessageScreen()),
            ),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const AiTranslatedText('Escrever', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF7B61FF),
          ),
        );
      },
    );
  }

  // Build the Outlook-style Sidebar Navigation
  Widget _buildSidebar({
    required BuildContext context,
    required List<String> themes,
    required int inboxUnread,
    required bool isDrawer,
  }) {
    return Container(
      width: isDrawer ? null : 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withValues(alpha: 0.4),
        border: isDrawer
            ? null
            : const Border(right: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          if (!isDrawer) ...[
            const Row(
              children: [
                Icon(Icons.mail, color: Color(0xFF7B61FF), size: 28),
                SizedBox(width: 12),
                Text(
                  'Outlook Mail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          const Text(
            'Pastas',
            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          _buildFolderTile(
            icon: Icons.inbox,
            title: 'Caixa de Entrada',
            folderKey: 'inbox',
            badgeCount: inboxUnread,
            isDrawer: isDrawer,
          ),
          _buildFolderTile(
            icon: Icons.send_rounded,
            title: 'Enviados',
            folderKey: 'sent',
            isDrawer: isDrawer,
          ),
          _buildFolderTile(
            icon: Icons.archive_outlined,
            title: 'Arquivo',
            folderKey: 'archive',
            isDrawer: isDrawer,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Temas',
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              if (_selectedThemeFilter != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedThemeFilter = null;
                    });
                  },
                  child: const Text(
                    'Limpar',
                    style: TextStyle(color: Color(0xFF00D1FF), fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (themes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Nenhum tema classificado ainda. Use a etiqueta em qualquer e-mail para organizar!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...themes.map((theme) {
              final isSelected = _selectedThemeFilter == theme;
              final themeColor = _getThemeColor(theme);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    Icons.label,
                    color: themeColor,
                    size: 18,
                  ),
                  title: Text(
                    theme,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedThemeFilter = theme;
                    });
                    if (isDrawer) Navigator.pop(context);
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  // Helper folder selector button
  Widget _buildFolderTile({
    required IconData icon,
    required String title,
    required String folderKey,
    int badgeCount = 0,
    required bool isDrawer,
  }) {
    final isSelected = _activeFolder == folderKey && _selectedThemeFilter == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF7B61FF).withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF7B61FF).withValues(alpha: 0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF7B61FF) : Colors.white54,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4A4A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _activeFolder = folderKey;
            _selectedThemeFilter = null; // Clear theme override
          });
          if (isDrawer) Navigator.pop(context);
        },
      ),
    );
  }

  // Build the message list view
  Widget _buildMessageList({
    required BuildContext context,
    required List<InternalMessage> messages,
    required FirebaseService service,
    required String userId,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 72, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text(
              'Nenhum e-mail nesta pasta ou tema',
              style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Experimente classificar ou arquivar os seus e-mails.',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isRead = msg.readBy.contains(userId);
        final isSender = msg.senderId == userId;
        final isArchived = msg.archivedBy.contains(userId);
        final msgTheme = msg.userThemes[userId];

        return Container(
          decoration: BoxDecoration(
            color: isRead
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? Colors.white10
                  : const Color(0xFF7B61FF).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (!isRead && !isSender) {
                service.markMessageRead(userId, msg.id);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageDetailScreen(message: msg),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Sender & Date & Unread Indicator
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isRead
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFF7B61FF),
                        child: Text(
                          msg.senderName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSender) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Enviado',
                                      style: TextStyle(color: Colors.white54, fontSize: 9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(msg.timestamp),
                              style: const TextStyle(color: Colors.white30, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Theme pill / tag selector
                      if (msgTheme != null)
                        GestureDetector(
                          onTap: () => _openThemeSelector(context, service, userId, msg),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getThemeColor(msgTheme).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getThemeColor(msgTheme).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.label, size: 10, color: _getThemeColor(msgTheme)),
                                const SizedBox(width: 4),
                                Text(
                                  msgTheme,
                                  style: TextStyle(
                                    color: _getThemeColor(msgTheme),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.label_outline, color: Colors.white38, size: 20),
                          tooltip: 'Adicionar Tema',
                          onPressed: () => _openThemeSelector(context, service, userId, msg),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Subject & message body teaser
                  Text(
                    msg.subject,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.body,
                    style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Row 3: Action Buttons (Archive, Theme tagger, Delete)
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(
                            isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                            size: 16,
                            color: const Color(0xFF00D1FF),
                          ),
                          label: Text(
                            isArchived ? 'Desarquivar' : 'Arquivar',
                            style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 12),
                          ),
                          onPressed: () async {
                            await service.archiveMessageForUser(userId, msg.id, !isArchived);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isArchived
                                      ? 'Mensagem restaurada para a Caixa de Entrada'
                                      : 'Mensagem arquivada com sucesso!'),
                                  backgroundColor: const Color(0xFF00D1FF),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.label,
                            size: 16,
                            color: Color(0xFF7B61FF),
                          ),
                          label: const Text(
                            'Tema',
                            style: TextStyle(color: Color(0xFF7B61FF), fontSize: 12),
                          ),
                          onPressed: () => _openThemeSelector(context, service, userId, msg),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4A4A), size: 18),
                          tooltip: 'Excluir',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Excluir Mensagem', style: TextStyle(color: Colors.white)),
                                content: const Text('Tem certeza de que deseja excluir este e-mail?', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4A4A)),
                                    child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                                    onPressed: () {
                                      service.deleteMessageForUser(userId, msg.id);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Mensagem excluída')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hoje às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
