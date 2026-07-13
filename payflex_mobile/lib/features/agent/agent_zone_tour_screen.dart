import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import 'agent_client_detail_screen.dart';

class AgentZoneTourScreen extends ConsumerStatefulWidget {
  const AgentZoneTourScreen({super.key});

  @override
  ConsumerState<AgentZoneTourScreen> createState() => _AgentZoneTourScreenState();
}

class _AgentZoneTourScreenState extends ConsumerState<AgentZoneTourScreen> {
  final _api = MobileApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final d = await _api.fetchAgentZoneTour(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );
    if (mounted) {
      setState(() {
        _data = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _data?['hasData'] == true;
    final sectors = hasData && _data!['collectSectors'] is List ? _data!['collectSectors'] as List : <dynamic>[];
    final clients = hasData && _data!['clients'] is List ? _data!['clients'] as List : <dynamic>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Zones de collecte', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!hasData)
                    Text('Aucune info à afficher', style: GoogleFonts.manrope(color: Colors.grey, fontWeight: FontWeight.w600))
                  else ...[
                    _card(
                      title: 'Zone principale',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_data!['zoneName'] ?? '—'}',
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary),
                          ),
                          if ((_data!['zoneDescription']?.toString().trim().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              _data!['zoneDescription'].toString(),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'Secteurs / quartiers',
                      child: sectors.isEmpty
                          ? Text('Aucun secteur renseigné (villes clients).', style: GoogleFonts.inter(color: const Color(0xFF64748B)))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: sectors.map((s) {
                                return Chip(
                                  label: Text(s.toString(), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'Clients rattachés (${clients.length})',
                      child: clients.isEmpty
                          ? Text('Aucun client dans votre zone.', style: GoogleFonts.inter(color: const Color(0xFF64748B)))
                          : Column(
                              children: clients.take(30).map((raw) {
                                final c = raw as Map;
                                final id = (c['id'] as num?)?.toInt();
                                final name = c['full_name']?.toString() ?? 'Client';
                                final city = c['city']?.toString() ?? '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14)),
                                  subtitle: city.isNotEmpty ? Text(city, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)) : null,
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: id == null
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AgentClientDetailScreen(
                                                clientId: id,
                                                name: name,
                                                zone: city,
                                              ),
                                            ),
                                          );
                                        },
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
