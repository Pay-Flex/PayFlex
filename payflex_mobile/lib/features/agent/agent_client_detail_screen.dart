import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/finance/client_bonus_savings_logic.dart';
import '../../core/widgets/client_bonus_savings_card.dart';
import '../../core/database/database_service.dart';
import '../../core/providers/agent_client_finance_provider.dart';
import '../../core/providers/agent_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'agent_add_product_screen.dart';
import 'agent_client_calendar_tab.dart';
import 'agent_client_history_tab.dart';
import 'agent_client_smartphone_tab.dart';
import 'agent_collect_screen.dart';
import 'agent_validation_queue_screen.dart';

class AgentClientDetailScreen extends ConsumerStatefulWidget {
  final int? clientId;
  final String name;
  final String zone;
  final bool isPhysical;

  const AgentClientDetailScreen({
    super.key,
    this.clientId,
    required this.name,
    required this.zone,
    this.isPhysical = true,
  });

  @override
  ConsumerState<AgentClientDetailScreen> createState() => _AgentClientDetailScreenState();
}

class _AgentClientDetailScreenState extends ConsumerState<AgentClientDetailScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  int? _selectedProductId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final auth = ref.read(authProvider);
    final cid = widget.clientId;
    if (auth.userId == null || cid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!silent && mounted) setState(() => _loading = _detail == null);
    final d = await ref.read(agentDataProvider.notifier).fetchClientDetail(cid);
    if (!mounted) return;
    setState(() {
      _detail = d;
      _loading = false;
      if (_selectedProductId == null && d?['products'] is List && (d!['products'] as List).isNotEmpty) {
        _selectedProductId = (((d['products'] as List).first as Map)['product_id'] as num?)?.toInt();
      }
    });
    if (d != null && d['hasData'] == true) {
      await _syncLocalFinance(d, cid, auth.userId!);
      await ref.read(agentClientFinanceProvider.notifier).loadForClient(cid);
    }
  }

  Future<void> _syncLocalFinance(Map<String, dynamic> detail, int clientId, int agentUserId) async {
    final products = detail['products'] is List ? detail['products'] as List : <dynamic>[];
    final productMaps = products.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    await _db.syncClientFinanceForAgent(
      serverClientUserId: clientId,
      clientName: detail['fullName']?.toString() ?? widget.name,
      agentUserId: agentUserId,
      products: productMaps,
      totalProject: (detail['totalProjectFcfa'] as num?)?.toDouble() ?? 0,
      dailyContribution: (detail['dailyContributionFcfa'] as num?)?.toDouble() ?? 0,
      collected: (detail['collectedFcfa'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get _hasData => _detail?['hasData'] == true;

  List<Map<String, dynamic>> get _products {
    if (!_hasData || _detail!['products'] is! List) return [];
    return (_detail!['products'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<int> get _paidDays {
    if (!_hasData || _detail!['paidDaysThisMonth'] is! List) return [];
    return (_detail!['paidDaysThisMonth'] as List).map((e) => (e as num).toInt()).toList();
  }

  List<int> get _catchupDays {
    if (!_hasData || _detail!['catchupDaysThisMonth'] is! List) return [];
    return (_detail!['catchupDaysThisMonth'] as List).map((e) => (e as num).toInt()).toList();
  }

  Set<int> _existingProductIds() {
    return _products.map((p) => (p['product_id'] as num?)?.toInt()).whereType<int>().toSet();
  }

  Future<void> _openCollect({required bool catchupMode}) async {
    final cid = widget.clientId;
    if (cid == null || !_hasData) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgentCollectScreen(
          clientName: _displayName(),
          clientId: cid,
          initialDailyRate: (_detail!['dailyContributionFcfa'] as num?)?.toDouble() ?? 200,
          products: _products,
          initialProductId: _selectedProductId,
          catchupMode: catchupMode,
          paidDays: _paidDays,
          catchupDays: _catchupDays,
          calendarYear: (_detail!['calendarYear'] as num?)?.toInt(),
          calendarMonth: (_detail!['calendarMonth'] as num?)?.toInt(),
        ),
      ),
    );
    if (changed == true) {
      await _load(silent: true);
      await ref.read(agentDataProvider.notifier).refresh(silent: true);
    }
  }

  Future<void> _openAddProduct() async {
    final cid = widget.clientId;
    if (cid == null || !_hasData) return;
    final updated = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AgentAddProductScreen(
          clientUserId: cid,
          clientName: _displayName(),
          currentTotalFcfa: (_detail!['totalProjectFcfa'] as num?)?.toDouble() ?? 0,
          currentDailyFcfa: (_detail!['dailyContributionFcfa'] as num?)?.toDouble() ?? 0,
          collectedFcfa: (_detail!['collectedFcfa'] as num?)?.toDouble() ?? 0,
          existingProductIds: _existingProductIds(),
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _detail = updated);
    } else {
      await _load(silent: true);
    }
  }

  Future<void> _callClient() async {
    final phone = _detail?['phone']?.toString().trim();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _fcfa(num? v) {
    if (v == null || v <= 0) return '0 FCFA';
    return '${v.toInt()} FCFA';
  }

  String _displayName() => _hasData && _detail!['fullName'] != null ? _detail!['fullName'].toString() : widget.name;

  String _displayZone() {
    if (_hasData) {
      final city = _detail!['city']?.toString();
      if (city != null && city.trim().isNotEmpty) return city;
    }
    return widget.zone.trim().isNotEmpty ? widget.zone : '—';
  }

  BonusSavingsSummary _bonusSummary(double daily) {
    final raw = _detail?['bonusSavings'];
    if (raw is Map) {
      return BonusSavingsSummary.fromMap(Map<String, dynamic>.from(raw));
    }
    final now = DateTime.now();
    final lines = _products
        .map(
          (p) => BonusSavingsLine(
            productName: p['name']?.toString() ?? 'Article',
            quantity: (p['quantity'] as num?)?.toInt() ?? 1,
            unitDailyMin: (p['daily_min'] as num?)?.toDouble() ?? 0,
            monthlyBonus: ClientBonusSavingsLogic.monthlyLineBonus(
              unitDailyMin: (p['daily_min'] as num?)?.toDouble() ?? 0,
              quantity: (p['quantity'] as num?)?.toInt() ?? 1,
            ),
          ),
        )
        .toList();
    return BonusSavingsSummary(
      monthlyFcfa: ClientBonusSavingsLogic.monthlyClientBonus(daily),
      officialDaysThisMonth: ClientBonusSavingsLogic.officialDaysInMonth(now.year, now.month),
      dailyContribution: daily,
      lines: lines,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_detail?['totalProjectFcfa'] as num?)?.toDouble() ?? 0;
    final collected = (_detail?['collectedFcfa'] as num?)?.toDouble() ?? 0;
    final remaining = (_detail?['remainingFcfa'] as num?)?.toDouble() ?? 0;
    final daily = (_detail?['dailyContributionFcfa'] as num?)?.toDouble() ?? 0;
    final progress = total > 0 ? (collected / total).clamp(0.0, 1.0) : 0.0;
    final estimatedDays = (_detail?['estimatedDaysRemaining'] as num?)?.toInt() ?? 0;
    final estimatedEnd = _detail?['estimatedEndDate']?.toString();
    final catchupPending = (_detail?['catchupPendingDays'] as num?)?.toInt() ?? 0;
    final selfManaged = _detail?['selfManaged'] == true;
    final initial = _displayName().trim().isNotEmpty ? _displayName().trim()[0].toUpperCase() : 'C';

    final cid = widget.clientId;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _loading && _detail == null
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, inner) => [
                  _buildSliverAppBar(initial),
                  if (_hasData)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          isScrollable: true,
                          labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 11),
                          tabs: const [
                            Tab(text: 'Résumé'),
                            Tab(text: 'Suivi'),
                            Tab(text: 'Historique'),
                            Tab(text: 'Smartphone'),
                          ],
                        ),
                      ),
                    ),
                ],
                body: !_hasData
                    ? ListView(padding: const EdgeInsets.all(20), children: [_emptyBanner()])
                    : TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: () => _load(silent: false),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                              children: [
                                _buildIdentityStrip(),
                                const SizedBox(height: 12),
                                _buildFinancialSummary(total, collected, remaining, progress, daily),
                                const SizedBox(height: 12),
                                _buildStatsRow(estimatedDays, estimatedEnd, catchupPending),
                                if (_bonusSummary(daily).hasData) ...[
                                  const SizedBox(height: 12),
                                  ClientBonusSavingsCard(summary: _bonusSummary(daily), compact: true, forAgent: true),
                                ],
                                const SizedBox(height: 20),
                                _buildSectionHeader('ARTICLES DU DOSSIER'),
                                const SizedBox(height: 12),
                                _buildProductList(),
                              ],
                            ),
                          ),
                          if (cid != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
                              child: AgentClientCalendarTab(
                                clientUserId: cid,
                                onCollectCatchup: hasCatchup ? () => _openCollect(catchupMode: true) : null,
                              ),
                            )
                          else const SizedBox.shrink(),
                          if (cid != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
                              child: AgentClientHistoryTab(clientUserId: cid),
                            )
                          else const SizedBox.shrink(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
                            child: AgentClientSmartphoneTab(detail: _detail),
                          ),
                        ],
                      ),
              ),
        bottomSheet: _hasData ? _buildActionBottomBar(selfManaged) : null,
      ),
    );
  }

  bool get hasCatchup => _catchupDays.isNotEmpty;

  Widget _buildIdentityStrip() {
    final phone = _detail?['phone']?.toString();
    final code = _detail?['uniqueCode']?.toString();
    final status = _detail?['status']?.toString();
    final adhesion = _detail?['adhesionFeePaid'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (phone != null && phone.isNotEmpty) _pill(Icons.phone_android_rounded, phone),
          if (code != null && code.isNotEmpty) _pill(Icons.tag_rounded, 'Dossier $code'),
          _pill(Icons.verified_user_outlined, adhesion ? 'Adhérent' : 'Adhésion due'),
          if (status != null) _pill(Icons.info_outline_rounded, status),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _emptyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Text('Aucune info à afficher', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.grey)),
    );
  }

  Widget _buildSliverAppBar(String initial) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.secondary,
      leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
      actions: [
        IconButton(onPressed: () => _load(silent: false), icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.85)])),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 36),
                CircleAvatar(radius: 40, backgroundColor: Colors.white24, child: Text(initial, style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
                const SizedBox(height: 10),
                Text(_displayName(), style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(_displayZone(), style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(double total, double collected, double remaining, double progress, double daily) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _financeStat('TOTAL', _fcfa(total.toInt())),
              _financeStat('PAYÉ', _fcfa(collected.toInt()), AppColors.primary),
              _financeStat('RESTE', _fcfa(remaining.toInt()), Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: const Color(0xFFF1F5F9), color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cotisation journalière', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
              Text('${daily.toInt()} F / jour', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildStatsRow(int estimatedDays, String? estimatedEnd, int catchupPending) {
    return Row(
      children: [
        Expanded(child: _statChip(Icons.timer_outlined, 'Jours restants', estimatedDays > 0 ? '$estimatedDays j' : '—')),
        const SizedBox(width: 8),
        Expanded(child: _statChip(Icons.event_outlined, 'Fin estimée', estimatedEnd ?? '—')),
        const SizedBox(width: 8),
        Expanded(child: _statChip(Icons.warning_amber_rounded, 'Rattrapage', catchupPending > 0 ? '$catchupPending j' : 'OK', catchupPending > 0 ? Colors.orange : Colors.green)),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, String value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.secondary),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? AppColors.secondary)),
        ],
      ),
    );
  }

  Widget _financeStat(String label, String value, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
        Text(value, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? AppColors.secondary)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2));
  }

  Widget _buildProductList() {
    if (_products.isEmpty) return Text('Aucun article', style: GoogleFonts.manrope(color: Colors.grey));
    return Column(
      children: _products.map((p) {
        final id = (p['product_id'] as num?)?.toInt();
        final selected = id == _selectedProductId;
        final name = p['name']?.toString() ?? 'Article';
        final remaining = (p['remaining_fcfa'] as num?)?.toInt() ?? 0;
        final progress = (p['progress_percent'] as num?)?.toInt() ?? 0;
        final lineTotal = (p['line_total'] as num?)?.toInt() ?? 0;
        final collectedP = (p['collected_fcfa'] as num?)?.toInt() ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: id == null ? null : () => setState(() => _selectedProductId = id),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200, width: selected ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primary : Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800))),
                      Text('$progress%', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress / 100, minHeight: 6, backgroundColor: const Color(0xFFF1F5F9), color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text('Payé $collectedP F · Reste $remaining F sur $lineTotal F', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBottomBar(bool selfManaged) {
    final phone = _detail?['phone']?.toString();
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    final hasCatchup = _catchupDays.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selfManaged)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentValidationQueueScreen())),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Valider cotisations smartphone'),
                ),
              ),
            ),
          Row(
            children: [
              if (hasPhone)
                IconButton.filledTonal(onPressed: _callClient, icon: const Icon(Icons.phone_rounded)),
              if (hasPhone) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasCatchup ? () => _openCollect(catchupMode: true) : null,
                  icon: const Icon(Icons.history_rounded),
                  label: Text(hasCatchup ? 'Rattraper (${_catchupDays.length})' : 'Rattraper'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isPhysical && widget.clientId != null ? () => _openCollect(catchupMode: false) : null,
                  icon: const Icon(Icons.payments_rounded, color: Colors.white),
                  label: const Text('Collecter'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(onPressed: _openAddProduct, icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('Ajouter un article')),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(color: const Color(0xFFF8FAFC), child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
