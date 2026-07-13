import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/network/mobile_api_service.dart';

class JobOfferDetailScreen extends StatefulWidget {
  const JobOfferDetailScreen({super.key, required this.offerId});

  final int offerId;

  @override
  State<JobOfferDetailScreen> createState() => _JobOfferDetailScreenState();
}

class _JobOfferDetailScreenState extends State<JobOfferDetailScreen> {
  final _api = MobileApiService();
  Map<String, dynamic>? _offer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.fetchJobOfferDetail(widget.offerId);
    if (!mounted) return;
    setState(() {
      _offer = data;
      _loading = false;
      _error = data == null ? 'Offre introuvable ou indisponible.' : null;
    });
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return '$base${path.startsWith('/') ? path : '/$path'}';
  }

  Future<void> _openDocument(String url, String name) async {
    final uri = Uri.parse(_resolveUrl(url));
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Détail de l\'offre',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.secondary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Text(
                      '${_offer!['title'] ?? ''}',
                      style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 12),
                    if ('${_offer!['period'] ?? ''}'.isNotEmpty)
                      _metaRow(Icons.date_range_outlined, 'Période', '${_offer!['period']}'),
                    if ('${_offer!['location'] ?? ''}'.isNotEmpty)
                      _metaRow(Icons.place_outlined, 'Lieu', '${_offer!['location']}'),
                    if ('${_offer!['profile_requirements'] ?? ''}'.isNotEmpty)
                      _metaRow(Icons.person_search_outlined, 'Profil', '${_offer!['profile_requirements']}'),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_offer!['description'] ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.55,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Documents',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 10),
                      ..._attachments.map(_documentTile),
                    ],
                  ],
                ),
    );
  }

  List<Map<String, dynamic>> get _attachments {
    final raw = _offer?['attachments'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                children: [
                  TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(Map<String, dynamic> att) {
    final name = '${att['file_name'] ?? 'Document'}';
    final url = '${att['file_url'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        title: Text(
          name,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.secondary),
        ),
        subtitle: Text(
          'Télécharger / ouvrir',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.download_rounded, color: AppColors.secondary),
        onTap: url.isEmpty ? null : () => _openDocument(url, name),
      ),
    );
  }
}
