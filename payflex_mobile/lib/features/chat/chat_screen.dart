import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/client_inbox_provider.dart';
import 'custom_request_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  int _lastMessageCount = 0;
  ChatNotifier? _chatNotifier;
  bool _sendingAttachment = false;

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatNotifier = ref.read(chatProvider.notifier);
      _chatNotifier!.startPolling();
      final auth = ref.read(authProvider);
      if (auth.role == 'client') {
        ref.read(clientInboxProvider.notifier).markChatRead();
      }
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).stopPolling();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteThread() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Effacer la discussion', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text(
          'Tous les messages avec le support seront supprimés. Cette action est irréversible.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref.read(chatProvider.notifier).deleteThread();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Discussion effacée.' : 'Suppression impossible. Réessayez.'),
        backgroundColor: success ? AppColors.success : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteMessage(Message msg) async {
    if (msg.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ce message', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text('Retirer ce message de la conversation ?', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref.read(chatProvider.notifier).deleteMessage(msg.id!);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suppression impossible. Réessayez.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(_controller.text.trim());
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _scrollToBottom();
    });
  }

  Future<void> _pickAndSendAttachment(Future<File?> Function() pick) async {
    if (_sendingAttachment) return;
    final file = await pick();
    if (file == null || !mounted) return;
    setState(() => _sendingAttachment = true);
    final caption = _controller.text.trim().isEmpty ? null : _controller.text.trim();
    final ok = await ref.read(chatProvider.notifier).sendAttachment(file, caption: caption);
    if (!mounted) return;
    setState(() => _sendingAttachment = false);
    if (ok && caption != null) _controller.clear();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Envoi du fichier impossible. Vérifiez le type (image, audio, document) et la taille (max 15 Mo).'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _scrollToBottom();
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Joindre un fichier', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.secondary),
                title: const Text('Photo (galerie)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendAttachment(() async {
                    final x = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    return x != null ? File(x.path) : null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.secondary),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendAttachment(() async {
                    final x = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    return x != null ? File(x.path) : null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined, color: AppColors.secondary),
                title: const Text('Fichier audio'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendAttachment(() async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'webm', 'amr', '3gp'],
                    );
                    final path = res?.files.single.path;
                    return path != null ? File(path) : null;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.secondary),
                title: const Text('Document (PDF, Word, etc.)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendAttachment(() async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const [
                        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', 'odt', 'ods',
                      ],
                    );
                    final path = res?.files.single.path;
                    return path != null ? File(path) : null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveAttachmentUrl(Message msg) {
    if (msg.localFilePath != null && msg.localFilePath!.isNotEmpty) {
      return msg.localFilePath!;
    }
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${url.startsWith('/') ? url : '/$url'}';
  }

  void _showImagePreview(String source) {
    final isNetwork = source.startsWith('http://') || source.startsWith('https://');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: isNetwork
                  ? Image.network(source, fit: BoxFit.contain)
                  : Image.file(File(source), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    if (messages.length != _lastMessageCount) {
      final grew = messages.length > _lastMessageCount;
      _lastMessageCount = messages.length;
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom(animated: _lastMessageCount > 1);
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('Support PayFlex',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF48BB78), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('En ligne', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF48BB78), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.secondary),
            onSelected: (value) async {
              if (value == 'clear') await _confirmDeleteThread();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Effacer la discussion'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière Demande Personnalisée
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomRequestScreen())),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondary.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.stars_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Produit non trouvé ?',
                          style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Faites une demande personnalisée ici',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.2),

          // Liste des messages
          Expanded(
            child: messages.isEmpty
              ? _buildEmptyChat()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderRole == 'user';
                    return _buildMessageBubble(msg, isMe);
                  },
                ),
          ),

          // Zone de saisie
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Écrivez au support PayFlex : un membre de l’équipe pourra vous répondre depuis l’administration.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          const SizedBox(height: 8),
          Text('Joignez une image, un audio ou un document via le bouton +.\nAppui long sur un message pour le supprimer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(Message msg, bool isMe) {
    final kind = msg.attachmentKind ?? 'document';
    final source = _resolveAttachmentUrl(msg);
    final name = msg.attachmentName ?? 'Fichier';
    final textColor = isMe ? Colors.white : AppColors.secondary;
    final subColor = isMe ? Colors.white.withOpacity(0.75) : Colors.grey.shade600;

    if (kind == 'image' && source.isNotEmpty) {
      final isNetwork = source.startsWith('http://') || source.startsWith('https://');
      return GestureDetector(
        onTap: () => _showImagePreview(source),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isNetwork
              ? Image.network(source, width: 180, height: 140, fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null ? child : const SizedBox(
                    width: 180, height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorBuilder: (_, __, ___) => _attachmentFallback(Icons.broken_image_outlined, 'Image', textColor, subColor),
                )
              : Image.file(File(source), width: 180, height: 140, fit: BoxFit.cover),
        ),
      );
    }

    IconData icon;
    String label;
    if (kind == 'audio') {
      icon = Icons.mic_rounded;
      label = 'Message vocal';
    } else {
      icon = Icons.insert_drive_file_rounded;
      label = 'Document';
    }
    return _attachmentFallback(icon, label, textColor, subColor, subtitle: name);
  }

  Widget _attachmentFallback(IconData icon, String label, Color textColor, Color subColor, {String? subtitle}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: textColor, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: subColor, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: msg.id != null ? () => _confirmDeleteMessage(msg) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.hasAttachment) ...[
                _buildAttachmentPreview(msg, isMe),
                if (msg.text.isNotEmpty && msg.text != 'Envoi du fichier…') const SizedBox(height: 8),
              ],
              if (msg.text.isNotEmpty)
                Text(msg.text,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white : AppColors.secondary,
                    fontSize: 14,
                    height: 1.4,
                  )),
              const SizedBox(height: 4),
              Text('${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isMe ? Colors.white.withOpacity(0.5) : Colors.grey.shade400,
                  fontSize: 9,
                )),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: isMe ? 0.1 : -0.1);
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _sendingAttachment ? null : _showAttachmentOptions,
            icon: _sendingAttachment
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondary, size: 28),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tapez un message...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
