import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
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
  int _lastMessageCount = 0;
  ChatNotifier? _chatNotifier;

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
          Text('Appui long sur un message pour le supprimer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
            ),
        ],
      ),
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
