import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/client_inbox_provider.dart';
import '../../core/providers/client_notifications_provider.dart';
import 'notification_navigation.dart';

class ClientNotificationsScreen extends ConsumerStatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  ConsumerState<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends ConsumerState<ClientNotificationsScreen> {
  Timer? _holdTimer;
  bool _longPressHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientNotificationsProvider.notifier).refresh(silent: false, unreadOnly: false);
      ref.read(clientInboxProvider.notifier).refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  int? _notificationId(Map<String, dynamic> n) => (n['id'] as num?)?.toInt();

  bool _isRead(Map<String, dynamic> n) => n['read'] == true;

  Future<void> _onTap(Map<String, dynamic> n) async {
    final id = _notificationId(n);
    if (id != null && !_isRead(n)) {
      await ref.read(clientNotificationsProvider.notifier).markOneRead(id);
    }
    if (!mounted) return;
    await navigateForClientNotification(context, ref, n);
  }

  void _onTapDown(Map<String, dynamic> n) {
    _longPressHandled = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _longPressHandled = true;
      HapticFeedback.heavyImpact();
      _showLongPressMenu(n);
    });
  }

  void _onTapEnd(Map<String, dynamic> n) {
    _holdTimer?.cancel();
    if (!_longPressHandled) {
      _onTap(n);
    }
  }

  Future<void> _showLongPressMenu(Map<String, dynamic> n) async {
    final id = _notificationId(n);
    if (id == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                (n['title'] ?? 'Notification').toString(),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isRead(n))
              ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined, color: AppColors.secondary),
                title: Text('Marquer comme non lu', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'unread'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
              title: Text(
                'Supprimer',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: Colors.red.shade700),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'unread') {
      final ok = await ref.read(clientNotificationsProvider.notifier).markOneUnread(id);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de marquer comme non lu.')),
        );
      }
    } else if (action == 'delete') {
      final ok = await ref.read(clientNotificationsProvider.notifier).deleteOne(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Notification supprimée.' : 'Suppression impossible.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = ref.watch(clientNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notif.unreadCount > 0)
            TextButton(
              onPressed: () async {
                await ref.read(clientNotificationsProvider.notifier).markAllRead();
              },
              child: Text(
                'Tout lu',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: notif.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notif.items.isEmpty
              ? Center(
                  child: Text(
                    'Aucune notification pour le moment.',
                    style: GoogleFonts.manrope(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(clientNotificationsProvider.notifier).refresh(unreadOnly: false),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: notif.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final n = notif.items[i];
                      final isRead = _isRead(n);
                      return GestureDetector(
                        onTapDown: (_) => _onTapDown(n),
                        onTapUp: (_) => _onTapEnd(n),
                        onTapCancel: () => _holdTimer?.cancel(),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRead
                                  ? const Color(0xFF38A169).withValues(alpha: 0.35)
                                  : Colors.red.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isRead ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isRead ? const Color(0xFF38A169) : Colors.red.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (n['title'] ?? 'Notification').toString(),
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (n['body'] ?? '').toString(),
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Appuyez pour ouvrir · maintenez 3 s pour plus d’options',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
