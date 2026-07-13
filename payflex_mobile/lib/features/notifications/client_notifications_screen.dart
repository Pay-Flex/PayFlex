import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/client_inbox_provider.dart';
import '../../core/providers/client_notifications_provider.dart';
import 'notification_navigation.dart';

class ClientNotificationsScreen extends ConsumerStatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  ConsumerState<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends ConsumerState<ClientNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientNotificationsProvider.notifier).refresh(silent: false, unreadOnly: false);
      ref.read(clientInboxProvider.notifier).refresh(silent: true);
    });
  }

  int? _notificationId(Map<String, dynamic> n) => (n['id'] as num?)?.toInt();

  bool _isRead(Map<String, dynamic> n) => n['read'] == true;

  bool _isPinned(Map<String, dynamic> n) => n['pinned'] == true;

  Future<void> _onTap(Map<String, dynamic> n) async {
    final id = _notificationId(n);
    if (id != null && !_isRead(n)) {
      await ref.read(clientNotificationsProvider.notifier).markOneRead(id);
    }
    if (!mounted) return;
    await navigateForClientNotification(context, ref, n);
  }

  Future<bool> _confirmDelete(Map<String, dynamic> n) async {
    final title = (n['title'] ?? 'Notification').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer la notification ?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          '« $title » sera définitivement retirée de votre liste.',
          style: GoogleFonts.manrope(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<bool?> _onDismissConfirm(DismissDirection direction, Map<String, dynamic> n) async {
    final id = _notificationId(n);
    if (id == null) return false;

    if (direction == DismissDirection.endToStart) {
      final confirmed = await _confirmDelete(n);
      if (!confirmed) return false;
      HapticFeedback.mediumImpact();
      final ok = await ref.read(clientNotificationsProvider.notifier).deleteOne(id);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible.')),
        );
      }
      return ok;
    }

    if (direction == DismissDirection.startToEnd) {
      HapticFeedback.lightImpact();
      final ok = await ref.read(clientNotificationsProvider.notifier).togglePin(id);
      if (mounted) {
        final pinned = !_isPinned(n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? (pinned ? 'Notification épinglée (suivi activé).' : 'Notification retirée du suivi.')
                  : 'Impossible de modifier le suivi.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    return false;
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
            ListTile(
              leading: Icon(
                _isPinned(n) ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                _isPinned(n) ? 'Retirer du suivi' : 'Épingler / mettre en suivi',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, 'pin'),
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

    if (action == 'pin') {
      final wasPinned = _isPinned(n);
      final ok = await ref.read(clientNotificationsProvider.notifier).togglePin(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? (wasPinned ? 'Retirée du suivi.' : 'Épinglée pour suivi.')
                  : 'Action impossible.',
            ),
          ),
        );
      }
    } else if (action == 'unread') {
      final ok = await ref.read(clientNotificationsProvider.notifier).markOneUnread(id);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de marquer comme non lu.')),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await _confirmDelete(n);
      if (!confirmed || !mounted) return;
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

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700)),
          ] else ...[
            Text(label, style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 26),
          ],
        ],
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n) {
    final isRead = _isRead(n);
    final isPinned = _isPinned(n);

    return GestureDetector(
      onTap: () => _onTap(n),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showLongPressMenu(n);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPinned
                ? AppColors.primary.withValues(alpha: 0.55)
                : isRead
                    ? const Color(0xFF38A169).withValues(alpha: 0.35)
                    : Colors.red.withValues(alpha: 0.25),
            width: isPinned ? 1.5 : 1,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (n['title'] ?? 'Notification').toString(),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primary),
                        ),
                    ],
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
                  const SizedBox(height: 8),
                  Text(
                    'Appuyez pour ouvrir · appui long pour plus d\'options',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notif = ref.watch(clientNotificationsProvider);
    final isAgent = ref.watch(authProvider).role == 'agent';
    final screenTitle = isAgent ? 'Alertes clients' : 'Notifications';
    final emptyHint = isAgent
        ? 'Les actions de vos clients (cotisations, inscriptions, messages) apparaîtront ici.'
        : 'Vous serez notifié des validations, messages et mises à jour PayFlex.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          screenTitle,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      emptyHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(color: Colors.grey.shade600),
                    ),
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
                      final id = _notificationId(n);
                      if (id == null) return _notificationCard(n);

                      return Dismissible(
                        key: ValueKey('notif-$id'),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) => _onDismissConfirm(direction, n),
                        background: _swipeBackground(
                          alignment: Alignment.centerLeft,
                          color: AppColors.primary,
                          icon: _isPinned(n) ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                          label: _isPinned(n) ? 'Retirer suivi' : 'Épingler',
                        ),
                        secondaryBackground: _swipeBackground(
                          alignment: Alignment.centerRight,
                          color: Colors.red.shade600,
                          icon: Icons.delete_outline_rounded,
                          label: 'Supprimer',
                        ),
                        child: _notificationCard(n),
                      );
                    },
                  ),
                ),
    );
  }
}
