import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/internal_message.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import 'compose_message_screen.dart';

class MessageDetailScreen extends StatelessWidget {
  final InternalMessage message;

  const MessageDetailScreen({super.key, required this.message});

  void _viewFullImage(BuildContext context, String base64OrUrl, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: base64OrUrl.startsWith('data:')
                    ? Image.memory(base64Decode(base64OrUrl.split(',').last))
                    : Image.network(base64OrUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachmentFile(BuildContext context, Map<String, String> att) async {
    try {
      final name = att['name'] ?? 'file';
      final data = att['data'] ?? '';
      
      if (data.startsWith('data:')) {
        final parts = data.split(',');
        if (parts.length == 2) {
          final bytes = base64Decode(parts[1]);
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$name');
          await tempFile.writeAsBytes(bytes);
          await OpenFilex.open(tempFile.path);
        }
      } else if (data.startsWith('http')) {
        await launchUrl(Uri.parse(data), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o ficheiro: $e')),
      );
    }
  }

  Color _getThemeColor(String theme) {
    final clean = theme.trim().toLowerCase();
    switch (clean) {
      case 'urgente':
      case 'urgent':
      case 'importante':
        return const Color(0xFFFF4A4A);
      case 'trabalho':
      case 'work':
      case 'profissional':
        return const Color(0xFF00D1FF);
      case 'financeiro':
      case 'finanças':
      case 'pagamentos':
      case 'finance':
        return const Color(0xFF00FF87);
      case 'académico':
      case 'academics':
      case 'escola':
      case 'estudos':
        return const Color(0xFF7B61FF);
      case 'pessoal':
      case 'personal':
        return const Color(0xFFFFA800);
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
    final userId = service.currentUser?.uid ?? '';

    return StreamBuilder<InternalMessage>(
      stream: service.getMessageStream(message.id),
      initialData: message,
      builder: (context, snapshot) {
        final msg = snapshot.data ?? message;
        final isArchived = msg.archivedBy.contains(userId);
        final msgTheme = msg.userThemes[userId];

        final List<Map<String, String>> attachmentsList = [];
        for (var attStr in msg.attachments) {
          try {
            final Map<String, dynamic> map = jsonDecode(attStr);
            attachmentsList.add({
              'name': map['name']?.toString() ?? '',
              'type': map['type']?.toString() ?? '',
              'data': map['data']?.toString() ?? '',
            });
          } catch (_) {
            attachmentsList.add({
              'name': attStr.split('/').last,
              'type': (attStr.endsWith('.png') || attStr.endsWith('.jpg') || attStr.endsWith('.jpeg')) ? 'image' : 'file',
              'data': attStr,
            });
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const AiTranslatedText('Detalhes do E-mail'),
            actions: [
              IconButton(
                tooltip: isArchived ? 'Desarquivar' : 'Arquivar',
                icon: Icon(
                  isArchived ? Icons.unarchive : Icons.archive,
                  color: const Color(0xFF00D1FF),
                ),
                onPressed: () async {
                  await service.archiveMessageForUser(userId, msg.id, !isArchived);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArchived
                            ? 'Mensagem movida para a Caixa de Entrada'
                            : 'Mensagem arquivada com sucesso!'),
                        backgroundColor: const Color(0xFF00D1FF),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'Classificar Tema',
                icon: const Icon(Icons.label, color: Color(0xFF7B61FF)),
                onPressed: () => _openThemeSelector(context, service, userId, msg),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF4A4A)),
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
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Return to communications list
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  msg.subject,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (msgTheme != null)
                                GestureDetector(
                                  onTap: () => _openThemeSelector(context, service, userId, msg),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                        Icon(Icons.label, size: 12, color: _getThemeColor(msgTheme)),
                                        const SizedBox(width: 6),
                                        Text(
                                          msgTheme,
                                          style: TextStyle(
                                            color: _getThemeColor(msgTheme),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 32),
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF7B61FF),
                                child: Text(
                                    msg.senderName
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg.senderName,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                    Text(_formatDate(msg.timestamp),
                                        style: const TextStyle(
                                            color: Colors.white54, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const AiTranslatedText('Para:',
                              style:
                                  TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(
                            '${msg.recipientIds.length} destinatários',
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
                    child: _buildBodyWithInlineImages(msg.body),
                  ),
                  if (attachmentsList.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    const Text(
                      'Anexos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attachmentsList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final att = attachmentsList[index];
                        final isImage = att['type'] == 'image';
                        final dataStr = att['data'] ?? '';
                        final name = att['name'] ?? '';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: Icon(
                                  isImage ? Icons.image : Icons.insert_drive_file,
                                  color: const Color(0xFF00D1FF),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  isImage ? 'Visualizar Imagem (Toque para ampliar)' : 'Documento / Ficheiro',
                                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isImage ? Icons.zoom_in : Icons.open_in_new,
                                    color: const Color(0xFF7B61FF),
                                  ),
                                  onPressed: () {
                                    if (isImage) {
                                      _viewFullImage(context, dataStr, name);
                                    } else {
                                      _openAttachmentFile(context, att);
                                    }
                                  },
                                ),
                                onTap: () {
                                  if (isImage) {
                                    _viewFullImage(context, dataStr, name);
                                  } else {
                                    _openAttachmentFile(context, att);
                                  }
                                },
                              ),
                              if (isImage && dataStr.startsWith('data:'))
                                GestureDetector(
                                  onTap: () => _viewFullImage(context, dataStr, name),
                                  child: Container(
                                    width: double.infinity,
                                    height: 180,
                                    margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(dataStr.split(',').last),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                )
                              else if (isImage && dataStr.startsWith('http'))
                                GestureDetector(
                                  onTap: () => _viewFullImage(context, dataStr, name),
                                  child: Container(
                                    width: double.infinity,
                                    height: 180,
                                    margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        dataStr,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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
                onPressed: () => _handleReply(context, msg, replyAll: true),
                icon: const Icon(Icons.reply_all, color: Colors.white),
                label: const AiTranslatedText('Responder a Todos', style: TextStyle(color: Colors.white)),
                backgroundColor: const Color(0xFF00D1FF),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'reply',
                onPressed: () => _handleReply(context, msg, replyAll: false),
                icon: const Icon(Icons.reply, color: Colors.white),
                label: const AiTranslatedText('Responder', style: TextStyle(color: Colors.white)),
                backgroundColor: const Color(0xFF7B61FF),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleReply(BuildContext context, InternalMessage msg, {required bool replyAll}) {
    List<String> toIds = [msg.senderId];
    List<String> ccIds = [];

    if (replyAll) {
      ccIds.addAll(msg.recipientIds);
      ccIds.addAll(msg.ccIds);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeMessageScreen(
          initialRecipientIds: toIds,
          initialCcIds: ccIds.isNotEmpty ? ccIds : null,
          initialSubject: msg.subject.startsWith('Re:')
              ? msg.subject
              : 'Re: ${msg.subject}',
        ),
      ),
    );
  }

  Widget _buildBodyWithInlineImages(String bodyText) {
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    final matches = imageRegex.allMatches(bodyText);

    if (matches.isEmpty) {
      return SelectableText(
        bodyText,
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
      );
    }

    final List<Widget> widgets = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        final textSegment = bodyText.substring(lastMatchEnd, match.start);
        if (textSegment.trim().isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                textSegment,
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
              ),
            ),
          );
        }
      }

      final altText = match.group(1) ?? 'Imagem';
      final imageUrl = match.group(2) ?? '';

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imageUrl.startsWith('data:image/'))
                        Image.memory(
                          base64Decode(imageUrl.split(',').last),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'Erro ao carregar imagem embutida',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ),
                            );
                          },
                        )
                      else if (imageUrl.startsWith('http'))
                        Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'Erro ao carregar imagem externa',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
                          ),
                        ),
                      if (altText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: Colors.black26,
                          child: Text(
                            altText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < bodyText.length) {
      final textSegment = bodyText.substring(lastMatchEnd);
      if (textSegment.trim().isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(
              textSegment,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
