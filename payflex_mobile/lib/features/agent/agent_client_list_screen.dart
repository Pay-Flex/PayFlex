import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import 'agent_collect_screen.dart';
import 'agent_client_detail_screen.dart';

class AgentClientListScreen extends ConsumerStatefulWidget {
  const AgentClientListScreen({super.key});

  @override
  ConsumerState<AgentClientListScreen> createState() => _AgentClientListScreenState();
}

class _AgentClientListScreenState extends ConsumerState<AgentClientListScreen> {
  final DatabaseService _db = DatabaseService();
  final MobileApiService _api = MobileApiService();
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  int _adhesionFeeFcfa = 250;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      setState(() {
        _clients = [];
        _loading = false;
      });
      return;
    }
    List<Map<String, dynamic>> list = [];
    final remote = await _api.fetchAgentClients(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );
    if (remote != null && remote['items'] is List) {
      _adhesionFeeFcfa = (remote['adhesionFeeFcfa'] as num?)?.toInt() ?? 250;
      for (final item in remote['items'] as List) {
        if (item is Map) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      final local = await _db.getClientsForAgent(auth.userId!);
      list = local;
    }
    if (mounted) {
      setState(() {
        _clients = list;
        _loading = false;
      });
    }
  }

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

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      final name = (c['full_name'] ?? c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
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
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final client = _filtered[index];
                            final id = (client['id'] as num).toInt();
                            final name = (client['full_name'] ?? client['name'] ?? 'Client').toString();
                            final zone = (client['city'] ?? client['profession'] ?? '—').toString();
                            final paid = client['adhesion_fee_paid'] == true;
                            final status = (client['status'] ?? '').toString();
                            final img = 'https://i.pravatar.cc/150?u=$id';

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
                                                img: img,
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(img, width: 44, height: 44, fit: BoxFit.cover),
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
                                              builder: (context) => AgentCollectScreen(clientName: name, clientId: id),
                                            ),
                                          );
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
