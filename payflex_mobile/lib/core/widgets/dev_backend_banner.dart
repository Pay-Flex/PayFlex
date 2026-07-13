import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/payflex_navigator.dart';
import '../network/api_config.dart';
import '../network/mobile_api_service.dart';
import '../network/payflex_api_logger.dart';
import '../utils/user_visible_message.dart';
import 'dev_api_settings_sheet.dart';

/// Bandeau debug superposé si le backend est injoignable (souvent IP Wi‑Fi obsolète).
class DevBackendBanner extends StatefulWidget {
  const DevBackendBanner({super.key, this.child});

  final Widget? child;

  @override
  State<DevBackendBanner> createState() => _DevBackendBannerState();
}

class _DevBackendBannerState extends State<DevBackendBanner> {
  bool? _healthy;
  bool _checking = false;

  bool get _enabled {
    if (!kDebugMode || kIsWeb) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    if (ApiConfig.useAdbReverseOnAndroid || ApiConfig.useTunnelOnMobile) return false;
    if (ApiConfig.baseUrlFromEnv) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      _probe();
    }
  }

  Future<void> _probe() async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await MobileApiService().checkHealth();
    if (!mounted) return;
    if (!ok) {
      PayflexApiLogger.warn(
        'Backend injoignable (${ApiConfig.connectionMode}) → ${ApiConfig.baseUrl}',
      );
    }
    setState(() {
      _healthy = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!_enabled || _healthy != false || child == null) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 4,
            color: const Color(0xFFB45309),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: _checking ? null : _probe,
                onLongPress: () {
                  final ctx = payflexRootNavigatorKey.currentContext;
                  if (ctx != null) showDevApiSettingsSheet(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_checking)
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 1, right: 8),
                          child: Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                        ),
                      Expanded(
                        child: Text(
                          UserVisibleMessage.devBackendUnreachable,
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
