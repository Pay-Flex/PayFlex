import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/biometric_auth_service.dart';
import '../auth/login_screen.dart';
import 'agent_change_pin_screen.dart';
import 'agent_weekly_schedule_screen.dart';
import 'agent_zone_tour_screen.dart';

class AgentProfileScreen extends ConsumerStatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  ConsumerState<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends ConsumerState<AgentProfileScreen> {
  final MobileApiService _api = MobileApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await BiometricAuthService.isDeviceSupported();
    final enabled = await BiometricAuthService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final p = await _api.fetchAgentProfile(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );
    if (mounted) {
      setState(() {
        _profile = p;
        _loading = false;
      });
    }
  }

  bool get _hasData => _profile?['hasData'] == true;

  String _sectorsLabel() {
    if (!_hasData) return 'Aucune info à afficher';
    final label = _profile!['collectSectorsLabel']?.toString().trim();
    if (label != null && label.isNotEmpty) return label;
    final zone = _profile!['zoneName']?.toString().trim();
    return zone?.isNotEmpty == true ? zone! : 'Aucune info à afficher';
  }

  String _scheduleLabel() {
    if (!_hasData) return 'Aucune info à afficher';
    return _profile!['weeklyScheduleSummary']?.toString() ?? 'Non défini';
  }

  Map<String, String> _scheduleMap() {
    if (!_hasData || _profile!['weeklySchedule'] is! Map) return {};
    final raw = _profile!['weeklySchedule'] as Map;
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  Future<void> _toggleBiometric() async {
    if (!_biometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biométrie non disponible sur cet appareil.')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (_biometricEnabled) {
      await BiometricAuthService.setEnabled(false);
      if (mounted) setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentification biométrique désactivée.')),
      );
      return;
    }

    final ok = await BiometricAuthService.authenticate(
      reason: 'Activez la connexion biométrique PayFlex',
    );
    if (!ok) return;
    if (auth.userId == null || auth.phone == null || auth.pin == null) return;

    await BiometricAuthService.saveCredentials(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      role: auth.role ?? 'agent',
    );
    if (mounted) setState(() => _biometricEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentification biométrique activée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final displayName = _hasData
        ? (_profile!['fullName']?.toString().trim().isNotEmpty == true
            ? _profile!['fullName'].toString()
            : auth.name ?? 'Agent PayFlex')
        : (auth.name?.trim().isNotEmpty == true ? auth.name!.trim() : 'Agent PayFlex');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: () async {
                await _load();
                await _loadBiometricState();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: AppColors.secondary,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.secondary.withValues(alpha: 0.9),
                              AppColors.secondary,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white24,
                                child: Text(
                                  auth.avatarLetter,
                                  style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              Text(
                                '${auth.statusLabelFr()} · ${auth.roleLabelFr()}',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_hasData && (_profile!['cashDebtFcfa'] as num? ?? 0) > 0) ...[
                          _buildCashDebtBanner((_profile!['cashDebtFcfa'] as num).toInt()),
                          const SizedBox(height: 16),
                        ],
                        _buildStatsGrid(),
                        const SizedBox(height: 24),
                        _buildMenuSection('Paramètres de Tournée', [
                          _actionTile(
                            icon: Icons.map_outlined,
                            title: 'Zones de collecte',
                            trailing: _sectorsLabel(),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentZoneTourScreen())),
                          ),
                          _actionTile(
                            icon: Icons.schedule_rounded,
                            title: 'Planning hebdomadaire',
                            trailing: _scheduleLabel(),
                            onTap: () async {
                              final res = await Navigator.push<Map<String, dynamic>?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AgentWeeklyScheduleScreen(initialSchedule: _scheduleMap()),
                                ),
                              );
                              if (res != null && mounted) await _load();
                            },
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildMenuSection('Sécurité', [
                          _actionTile(
                            icon: Icons.lock_reset_rounded,
                            title: 'Modifier mon PIN Agent',
                            trailing: '',
                            onTap: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => const AgentChangePinScreen()),
                              );
                              if (ok == true && mounted) await _load();
                            },
                          ),
                          _actionTile(
                            icon: Icons.fingerprint_rounded,
                            title: 'Authentification biométrique',
                            trailing: _biometricEnabled ? 'Activée' : 'Désactivée',
                            onTap: _toggleBiometric,
                          ),
                        ]),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, color: AppColors.secondary),
                          label: Text(
                            'SE DÉCONNECTER',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.secondary),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE4E6),
                            foregroundColor: AppColors.secondary,
                            minimumSize: const Size(double.infinity, 58),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                        const SizedBox(height: 120),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCashDebtBanner(int amountFcfa) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFE11D48), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dette caisse : $amountFcfa FCFA',
                  style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF9F1239)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Écart constaté lors du rapprochement. Merci de rembourser ce montant au centre.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9F1239), height: 1.35),
                ),
                if (_lastRepaymentLabel() != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _lastRepaymentLabel()!,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFBE123C)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _lastRepaymentLabel() {
    if (!_hasData) return null;
    final amount = (_profile!['lastDebtRepaymentFcfa'] as num?)?.toInt();
    if (amount == null || amount <= 0) return null;
    final rawDate = _profile!['lastDebtRepaymentAt']?.toString();
    String? dateLabel;
    if (rawDate != null && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        dateLabel = '${parsed.day.toString().padLeft(2, '0')}/'
            '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      }
    }
    return dateLabel != null
        ? 'Dernier remboursement : $amount FCFA le $dateLabel.'
        : 'Dernier remboursement : $amount FCFA.';
  }

  Widget _buildStatsGrid() {
    final clients = _hasData ? (_profile!['clientsCount'] as num?)?.toInt() : null;
    final recovery = _hasData ? (_profile!['recoveryPercent'] as num?)?.toInt() : null;
    return Row(
      children: [
        _statBox(clients != null ? '$clients' : '—', 'CLIENTS SUIVIS'),
        const SizedBox(width: 12),
        _statBox(recovery != null ? '$recovery%' : '—', 'RECOUVREMENT'),
      ],
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.secondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Flexible(
              child: Text(
                trailing,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
        ],
      ),
    );
  }
}
