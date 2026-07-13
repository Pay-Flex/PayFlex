import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../network/api_config.dart';
import '../network/api_config_store.dart';
import '../network/mobile_api_service.dart';

/// Réglages debug : URL backend persistante (appui long sur le logo, écran connexion).
Future<void> showDevApiSettingsSheet(BuildContext context) async {
  if (!kDebugMode) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _DevApiSettingsSheet(),
  );
}

class _DevApiSettingsSheet extends StatefulWidget {
  const _DevApiSettingsSheet();

  @override
  State<_DevApiSettingsSheet> createState() => _DevApiSettingsSheetState();
}

class _DevApiSettingsSheetState extends State<_DevApiSettingsSheet> {
  late final TextEditingController _hostCtrl;
  bool _saving = false;
  bool _probing = false;
  String? _probeResult;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: _initialHostText());
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  String _initialHostText() {
    final override = ApiConfigStore.overrideUrl;
    if (override != null) {
      final uri = Uri.tryParse(override);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
      return override;
    }
    if (ApiConfig.devPcIpv4.isNotEmpty) return ApiConfig.devPcIpv4;
    return '';
  }

  Future<void> _applyUsb() async {
    await ApiConfigStore.setUsbReverseDefault();
    if (!mounted) return;
    setState(() => _hostCtrl.text = '127.0.0.1');
    _showSavedSnack('USB adb reverse (127.0.0.1:${ApiConfig.backendPort})');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _probeResult = null;
    });
    await ApiConfigStore.setFromUserInput(_hostCtrl.text);
    if (!mounted) return;
    setState(() => _saving = false);
    _showSavedSnack('URL enregistrée : ${ApiConfig.baseUrl}');
  }

  Future<void> _applyLocalTunnel() async {
    final preset = ApiConfig.defaultTunnelBase.trim();
    await ApiConfigStore.setOverride(preset);
    if (!mounted) return;
    final uri = Uri.tryParse(preset);
    setState(() => _hostCtrl.text = uri?.host ?? preset);
    _showSavedSnack('LocalTunnel : $preset');
  }

  Future<void> _clear() async {
    await ApiConfigStore.clearOverride();
    if (!mounted) return;
    setState(() => _hostCtrl.text = ApiConfig.devPcIpv4);
    _showSavedSnack('Override effacé — défauts dart-define / 127.0.0.1');
  }

  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _probeResult = null;
    });
    final ok = await MobileApiService().checkHealth();
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeResult = ok ? 'Backend joignable ✓' : 'Backend injoignable ✗';
    });
  }

  void _showSavedSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Backend dev (debug)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'IP ou URL du PC (port ${ApiConfig.backendPort}). '
            'Persiste après changement de Wi‑Fi — pas de recompilation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Actuel : ${ApiConfig.baseUrl}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Mode : ${ApiConfig.connectionMode}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'IP du PC ou URL complète',
              hintText: '192.168.0.42',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_saving,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _applyLocalTunnel,
                icon: const Icon(Icons.public, size: 18),
                label: const Text('LocalTunnel'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _applyUsb,
                icon: const Icon(Icons.usb, size: 18),
                label: const Text('USB 127.0.0.1'),
              ),
              OutlinedButton(
                onPressed: _saving ? null : _clear,
                child: const Text('Effacer override'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _probing ? null : _probe,
                child: _probing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tester'),
              ),
            ],
          ),
          if (_probeResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _probeResult!,
              style: TextStyle(
                color: _probeResult!.contains('✓')
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Astuce : ipconfig sur le PC → IPv4 Wi‑Fi. USB : adb reverse tcp:8088 tcp:8088 puis bouton USB.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
