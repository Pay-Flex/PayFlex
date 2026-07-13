import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/widgets/registration_form_theme.dart';

class AgentWeeklyScheduleScreen extends ConsumerStatefulWidget {
  const AgentWeeklyScheduleScreen({super.key, this.initialSchedule});

  final Map<String, String>? initialSchedule;

  @override
  ConsumerState<AgentWeeklyScheduleScreen> createState() => _AgentWeeklyScheduleScreenState();
}

class _AgentWeeklyScheduleScreenState extends ConsumerState<AgentWeeklyScheduleScreen> {
  static const _days = [
    ('lun', 'Lundi'),
    ('mar', 'Mardi'),
    ('mer', 'Mercredi'),
    ('jeu', 'Jeudi'),
    ('ven', 'Vendredi'),
    ('sam', 'Samedi'),
    ('dim', 'Dimanche'),
  ];

  final _api = MobileApiService();
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final d in _days) {
      final initial = widget.initialSchedule?[d.$1] ?? '';
      _controllers[d.$1] = TextEditingController(text: initial);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;

    final schedule = <String, String>{};
    for (final d in _days) {
      schedule[d.$1] = _controllers[d.$1]!.text.trim();
    }

    setState(() => _saving = true);
    try {
      final res = await _api.updateAgentWeeklySchedule(
        userId: auth.userId!,
        phone: auth.phone ?? '',
        pin: auth.pin ?? '',
        weeklySchedule: schedule,
      );
      if (!mounted) return;
      if (res == null || res['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message']?.toString() ?? 'Enregistrement impossible.')),
        );
        return;
      }
      Navigator.pop(context, res);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planning hebdomadaire enregistré.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserVisibleMessage.forException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Planning hebdomadaire', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          RegistrationFormTheme.infoBanner(
            'Indiquez vos tournées et secteurs par jour. Ces informations sont visibles sur votre profil agent.',
          ),
          const SizedBox(height: 16),
          ..._days.map((d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[d.$1],
                style: RegistrationFormTheme.fieldStyle(context),
                decoration: RegistrationFormTheme.labeled(d.$2, hint: 'Ex. Collecte secteur nord…'),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: RegistrationFormTheme.primaryActionButton(),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer le planning'),
          ),
        ),
      ),
    );
  }
}
