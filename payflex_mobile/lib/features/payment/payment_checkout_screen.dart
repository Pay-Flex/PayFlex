import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/network/mobile_api_service.dart';

enum PaymentCheckoutOutcome { validated, rejected, cancelled, pending }

class PaymentCheckoutResult {
  const PaymentCheckoutResult(this.outcome);
  final PaymentCheckoutOutcome outcome;
}

/// Paiement PayDunya intégré dans l'app (WebView) — l'utilisateur ne quitte pas PayFlex.
/// Sert aussi bien pour les cotisations que pour l'adhésion (250 FCFA).
class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.paymentUrl,
    required this.userId,
    required this.amountFcfa,
    this.contributionId = 0,
    this.adhesionMode = false,
    this.phone = '',
    this.pin = '',
    this.callbackUrl = '',
  });

  final String paymentUrl;
  final int contributionId;
  final int userId;
  final int amountFcfa;
  final bool adhesionMode;
  final String phone;
  final String pin;

  /// URL de retour PayFlex (tunnel) — détectée pour valider sans charger la page.
  final String callbackUrl;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final _api = MobileApiService();
  late final WebViewController _controller;
  var _loading = true;
  var _checking = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            final failedUrl = err.url ?? '';
            if (_isPaymentFinishedUrl(failedUrl) || _looksLikeCallbackFailure(err.description)) {
              _handleFinishedUrl(failedUrl);
              return;
            }
            if (mounted) {
              setState(() => _pageError = err.description);
            }
          },
          onUrlChange: (change) {
            final url = change.url ?? '';
            if (_isPaymentFinishedUrl(url)) {
              _handleFinishedUrl(url);
            }
          },
          onNavigationRequest: (request) {
            if (_isPaymentFinishedUrl(request.url)) {
              _handleFinishedUrl(request.url);
              return NavigationDecision.prevent;
            }
            if (ApiConfig.urlNeedsLocalTunnelBypass(request.url)) {
              _loadTunnelUrl(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadTunnelUrl(widget.paymentUrl);
  }

  void _loadTunnelUrl(String url) {
    final uri = Uri.parse(url);
    final headers = ApiConfig.localTunnelHeaders;
    if (headers.isEmpty) {
      _controller.loadRequest(uri);
    } else {
      _controller.loadRequest(uri, headers: headers);
    }
  }

  bool _looksLikeCallbackFailure(String? description) {
    final d = description?.toLowerCase() ?? '';
    if (!d.contains('connection_refused') && !d.contains('err_connection')) {
      return false;
    }
    final cb = widget.callbackUrl.trim().toLowerCase();
    return cb.isNotEmpty || d.contains('trycloudflare') || d.contains('paydunya/callback');
  }

  bool _isCanceledUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('status=canceled') || u.contains('status=cancelled');
  }

  bool _isPaymentFinishedUrl(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    final cb = widget.callbackUrl.trim().toLowerCase();
    if (cb.isNotEmpty && u.startsWith(cb)) {
      return true;
    }
    if (u.contains('paydunya/callback') ||
        u.contains('/contributions/paydunya/callback') ||
        u.contains('/adhesion/paydunya/callback')) {
      return true;
    }
    if (u.contains('status=approved') ||
        u.contains('status=completed') ||
        u.contains('status=success') ||
        u.contains('status=canceled') ||
        u.contains('status=cancelled')) {
      return true;
    }
    return false;
  }

  void _handleFinishedUrl(String url) {
    if (_isCanceledUrl(url) && widget.adhesionMode) {
      if (!mounted || _checking) return;
      Navigator.pop(context, const PaymentCheckoutResult(PaymentCheckoutOutcome.cancelled));
      return;
    }
    _verifyAndClose(auto: true);
  }

  Future<void> _verifyAndClose({bool auto = false}) async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _pageError = null;
    });
    PaymentCheckoutOutcome outcome = PaymentCheckoutOutcome.pending;
    final attempts = auto ? 10 : 4;
    for (var i = 0; i < attempts; i++) {
      if (!mounted) return;
      final Map<String, dynamic>? st;
      if (widget.adhesionMode) {
        st = await _api.paydunyaAdhesionStatus(
          userId: widget.userId,
          phone: widget.phone,
          pin: widget.pin,
        );
      } else {
        st = await _api.paydunyaContributionStatus(
          userId: widget.userId,
          contributionId: widget.contributionId,
        );
      }
      final status = st?['status']?.toString() ?? 'pending';
      final adhered = st?['adhesionFeePaid'] == true || status == 'adhered';
      if (status == 'validated' || adhered) {
        outcome = PaymentCheckoutOutcome.validated;
        break;
      }
      if (status == 'rejected') {
        outcome = PaymentCheckoutOutcome.rejected;
        break;
      }
      if (i < attempts - 1) {
        await Future.delayed(Duration(seconds: auto ? 3 : 2));
      }
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (outcome == PaymentCheckoutOutcome.validated ||
        outcome == PaymentCheckoutOutcome.rejected) {
      Navigator.pop(context, PaymentCheckoutResult(outcome));
      return;
    }
    if (!auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Paiement encore en attente. Si PayDunya affiche « succès », appuyez sur « J’ai terminé le paiement ».',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Paiement sécurisé',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _checking
              ? null
              : () => Navigator.pop(
                    context,
                    const PaymentCheckoutResult(PaymentCheckoutOutcome.cancelled),
                  ),
        ),
        actions: [
          TextButton(
            onPressed: _checking ? null : () => _verifyAndClose(),
            child: Text(
              _checking ? '…' : 'Vérifier',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFF1D4ED8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.amountFcfa} FCFA · Mobile money (PayDunya). Après paiement, appuyez sur « J’ai terminé le paiement ».',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E3A5F)),
                  ),
                ),
              ],
            ),
          ),
          if (_checking)
            LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          if (_pageError != null && !_checking)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Retour PayFlex indisponible (tunnel). Si le paiement PayDunya a réussi, '
                'utilisez le bouton ci-dessous.',
                style: GoogleFonts.inter(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading || _checking)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: _checking ? 0.75 : 0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (_checking) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Confirmation avec PayFlex…',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checking ? null : () => _verifyAndClose(),
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: Text(
                    _checking ? 'Vérification…' : 'J’ai terminé le paiement',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
