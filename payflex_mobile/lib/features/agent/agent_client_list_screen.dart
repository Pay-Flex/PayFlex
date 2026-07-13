import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/agent_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'agent_client_detail_screen.dart';

class AgentClientListScreen extends ConsumerStatefulWidget {
  const AgentClientListScreen({super.key});

  @override
  ConsumerState<AgentClientListScreen> createState() => _AgentClientListScreenState();
}

class _AgentClientListScreenState extends ConsumerState<AgentClientListScreen> {
  final DatabaseService _db = DatabaseService();
  final MobileApiService _api = MobileApiService();
  int _adhesionFeeFcfa = 250;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agentDataProvider.notifier).refresh(silent: false);
    });
  }

  Future<void> _loadClients() async => ref.read(agentDataProvider.notifier).refresh(silent: false);

  Future<void> _confirmAdhesionPaid(Map<String, dynamic> client) async {
    final auth = ref.read(authProvider);
    final clientId = (client['id'] as num?)?.toInt();
    if (clientId == null || auth.userId == null) return;
    final name = (client['full_name'] ?? client['name'] ?? 'Client').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adhésion payée'),
        content: Text(
          'Confirmer que $name vous a remis $_adhesionFeeFcfa FCFA en espèces pour son adhésion PayFlex ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, payé')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await _api.markClientAdhesionPaid(
      agentUserId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
      clientUserId: clientId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Adhésion enregistrée — client adhérent.')),
    );
    if (err == null) await _loadClients();
  }

  List<Map<String, dynamic>> _filteredClients(List<Map<String, dynamic>> clients) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients.where((c) {
      final name = (c['full_name'] ?? c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentDataProvider);
    final filtered = _filteredClients(agent.clients);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mes clients',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          Expanded(
            child: agent.isLoading && filtered.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Aucun client parrainné par vous.\nLes clients doivent vous choisir à l\'inscription pour apparaître ici.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(color: Colors.grey.shade600, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClients,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final client = filtered[index];
                            final id = (client['id'] as num).toInt();
                            final name = (client['full_name'] ?? client['name'] ?? 'Client').toString();
                            final zone = (client['city'] ?? client['profession'] ?? '—').toString();
                            final paid = client['adhesion_fee_paid'] == true;
                            final status = (client['status'] ?? '').toString();
                            final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.02), blurRadius: 10)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AgentClientDetailScreen(
                                                clientId: id,
                                                name: name,
                                                zone: zone,
                                              ),
                                            ),
                                          );
                                        },
                                        child: CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                          child: Text(
                                            initial,
                                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.secondary),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                            Text(zone, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                                            if (!paid || status != 'adhere')
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Adhésion $_adhesionFeeFcfa FCFA due',
                                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AgentClientDetailScreen(clientId: id, name: name, zone: zone),
                                            ),
                                          ).then((_) => ref.read(agentDataProvider.notifier).refresh(silent: true));
                                        },
                                        icon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  if (!paid)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () => _confirmAdhesionPaid(client),
                                          icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                                          label: Text('Adhésion payée ($_adhesionFeeFcfa FCFA)'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
