import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/client_inbox_provider.dart';
import '../../core/providers/client_notifications_provider.dart';
import '../../core/widgets/count_badge.dart';
import '../notifications/client_notifications_screen.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/agent_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'agent_registry_screen.dart';
import 'agent_validation_queue_screen.dart';
import 'agent_enrollment_screen.dart';
import 'agent_client_detail_screen.dart';
import '../support/client_report_screen.dart';
import '../vitrine/job_offers_screen.dart';
import '../../core/widgets/payflex_quick_access_row.dart';

class AgentDashboardScreen extends ConsumerStatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  ConsumerState<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends ConsumerState<AgentDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientInboxProvider.notifier).refresh(silent: true);
      ref.read(clientNotificationsProvider.notifier).refresh(silent: true, unreadOnly: false);
      ref.read(agentDataProvider.notifier).refresh(silent: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasDashboardData(Map<String, dynamic>? dashboard) => dashboard?['hasData'] == true;

  List<Map<String, dynamic>> _filteredClients(List<Map<String, dynamic>> clients) {
    if (_searchQuery.trim().isEmpty) return clients;
    final q = _searchQuery.toLowerCase();
    return clients.where((c) {
      final name = (c['full_name'] ?? c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final id = (c['id'] ?? '').toString();
      return name.contains(q) || phone.contains(q) || id.contains(q);
    }).toList();
  }

  String _formatFcfa(num? v) {
    if (v == null) return 'Aucune info à afficher';
    final n = v.toInt();
    if (n <= 0) return 'Aucune info à afficher';
    return '${_thousands(n)} FCFA';
  }

  String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatLastPayment(dynamic raw) {
    if (raw == null) return 'Aucune info à afficher';
    final s = raw.toString();
    if (s.isEmpty) return 'Aucune info à afficher';
    try {
      final dt = DateTime.parse(s.replaceFirst(' ', 'T'));
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return s.length > 16 ? s.substring(0, 16) : s;
    }
  }

  String _clientName(Map<String, dynamic> c) =>
      (c['full_name'] ?? c['name'] ?? 'Client').toString();

  String _clientZone(Map<String, dynamic> c) {
    final z = c['displayZone'] ?? c['city'] ?? c['profession'];
    if (z == null || z.toString().trim().isEmpty) return 'Aucune info à afficher';
    return z.toString();
  }
  
  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentDataProvider);
    final dashboard = agent.dashboard;
    final clients = _filteredClients(agent.clients);
    final hasDashboard = _hasDashboardData(dashboard);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Header Background avec léger dégradé
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.read(agentDataProvider.notifier).refresh(silent: false),
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // AppBar Agent (Toujours en haut)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final auth = ref.watch(authProvider);
                            return CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              child: Text(
                                auth.avatarLetter,
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Builder(
                          builder: (context) {
                            final auth = ref.watch(authProvider);
                            return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.roleLabelFr().toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.secondary.withOpacity(0.5),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              auth.name?.trim().isNotEmpty == true ? auth.name!.trim() : 'Agent PayFlex',
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                        const Spacer(),
                        _buildNotificationAction(context, ref),
                      ],
                    ),
                  ),
                ),

                // Stats Card "Elite" (Barre de progression)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Collecté aujourd\'hui',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondary.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasDashboard
                                        ? _formatFcfa(dashboard!['todayCollectedFcfa'] as num?)
                                        : 'Aucune info à afficher',
                                    style: GoogleFonts.manrope(
                                      fontSize: hasDashboard ? 32 : 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.secondary,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FAFC),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.analytics_outlined, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Barre de progression
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF2F7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: hasDashboard
                                        ? (((dashboard!['todayProgressPercent'] as num?) ?? 0) / 100).clamp(0.0, 1.0)
                                        : 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF48BB78), Color(0xFF68D391)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hasDashboard
                                    ? '${(dashboard!['todayProgressPercent'] as num?)?.toInt() ?? 0}%'
                                    : '—',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF48BB78),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DE L\'OBJECTIF JOURNALIER',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PayflexQuickAccessRow(
                      onReportTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientReportScreen()),
                      ),
                      onOpportunitiesTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JobOffersScreen()),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistryScreen())),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Registre des collectes', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                                  Text(
                                    '${agent.registry.length} opération(s) · MAJ auto',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Statistiques de l'agent (Collecté / Objectif en second)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildStatCard(
                          'COLLECTÉ',
                          hasDashboard
                              ? _formatFcfa(dashboard!['totalCollectedFcfa'] as num?)
                              : 'Aucune info à afficher',
                          Icons.account_balance_wallet_rounded,
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'OBJECTIF',
                          hasDashboard
                              ? _formatFcfa(dashboard!['terrainObjectiveFcfa'] as num?)
                              : 'Aucune info à afficher',
                          Icons.flag_rounded,
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                      ],
                    ),
                  ),
                ),

                // Button Enregistrer Client
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AgentEnrollmentScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Enregistrer un nouveau client'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                        side: BorderSide(color: AppColors.secondary.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        foregroundColor: AppColors.secondary,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Section List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Clients assignés',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '${clients.length} AU TOTAL',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recherche Client
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2F7).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Rechercher par Nom ou ID Client',
                          hintStyle: GoogleFonts.manrope(color: Colors.grey, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                ),
                if (agent.isLoading && clients.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (clients.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Aucune info à afficher',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final client = clients[index];
                          final id = (client['id'] as num).toInt();
                          final selfManaged = client['self_managed'] == true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildClientCard(
                              context,
                              id,
                              _clientName(client),
                              _clientZone(client),
                              _formatLastPayment(client['last_payment_at']),
                              !selfManaged,
                            ),
                          );
                        },
                        childCount: clients.length,
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.secondary, size: 22),
    );
  }

  Widget _buildNotificationAction(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(clientInboxProvider);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClientNotificationsScreen()),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHeaderAction(Icons.notifications_none_rounded),
          if (inbox.notificationsUnread > 0)
            CountBadge(count: inbox.notificationsUnread, top: -4, right: -4),
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, int clientDbId, String name, String zone, String lastPay, bool isPhysical) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgentClientDetailScreen(
              clientId: clientDbId,
              name: name,
              zone: zone,
              isPhysical: isPhysical,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 15)),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(zone, style: GoogleFonts.manrope(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DERNIER PAIEMENT', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text(
                      lastPay,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: lastPay == 'Aucune info à afficher' ? Colors.grey : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isPhysical)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AgentClientDetailScreen(
                        clientId: clientDbId,
                        name: name,
                        zone: zone,
                        isPhysical: isPhysical,
                      ),
                    ),
                  ).then((_) => ref.read(agentDataProvider.notifier).refresh(silent: true));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Valider la collecte', style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            )
          else if (!isPhysical)
             Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AgentValidationQueueScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDF2F7),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Voir la demande smartphone', style: GoogleFonts.manrope(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
