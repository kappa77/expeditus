import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dlna/dlna_models.dart';
import '../state/cast_controller.dart';
import '../theme.dart';

Future<bool?> showCastDialog(BuildContext context, CastController controller) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CastDialog(controller: controller),
  );
}

class CastDialog extends StatefulWidget {
  const CastDialog({super.key, required this.controller});

  final CastController controller;

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  DlnaDevice? _connecting;
  DlnaDevice? _failedDevice;
  String? _connectError;

  CastController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _controller;
      if (!controller.isConnected &&
          !controller.discovering &&
          !controller.hasDiscovered &&
          controller.devices.isEmpty) {
        unawaited(controller.discover());
      }
    });
  }

  Future<void> _connect(DlnaDevice device) async {
    if (_connecting != null) return;
    setState(() {
      _connecting = device;
      _failedDevice = null;
      _connectError = null;
    });
    final ok = await _controller.connect(device);
    if (!mounted) return;
    if (ok) {
      setState(() => _connecting = null);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _connecting = null;
      _failedDevice = device;
      _connectError = _controller.error ?? 'Aggancio non riuscito.';
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _connectError = null;
      _failedDevice = null;
    });
    await _controller.discover(force: true);
  }

  Future<void> _disconnect() async {
    unawaited(_controller.disconnect());
    Navigator.of(context).pop(false);
  }

  Future<void> _allowFirewall() async {
    final allowed = await _controller.allowFirewall();
    if (!mounted) return;
    if (allowed) {
      // The player restarts the current video after the dialog closes.
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _allowFirewallAndRefresh() async {
    final allowed = await _controller.allowFirewall();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _connectError = _controller.error);
      return;
    }
    await _controller.discover(force: true);
  }

  Future<void> _allowPrivateNetworkAndRefresh() async {
    final fixed = await _controller.allowPrivateNetwork();
    if (!mounted) return;
    if (!fixed) {
      setState(() => _connectError = _controller.error);
      return;
    }
    await _controller.discover(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: _connecting == null,
          child: Dialog(
            key: const Key('cast-dialog'),
            backgroundColor: ExpeditusColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ExpeditusColors.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _controller.isConnected
                              ? Icons.cast_connected_rounded
                              : Icons.cast_rounded,
                          size: 20,
                          color: ExpeditusColors.accent,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Trasmetti su dispositivo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Chiudi',
                          onPressed: _connecting == null
                              ? () => Navigator.of(context).pop(false)
                              : null,
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: _controller.isConnected
                            ? _buildConnected()
                            : _buildDiscovery(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnected() {
    final controller = _controller;
    final device = controller.device;
    final status = switch (controller.playback) {
      CastPlaybackState.starting => 'Avvio della riproduzione…',
      CastPlaybackState.playing => 'In riproduzione sul dispositivo',
      CastPlaybackState.paused => 'In pausa sul dispositivo',
      CastPlaybackState.stopped => 'Connesso, in attesa di avvio',
      CastPlaybackState.error => 'Errore sul dispositivo',
      CastPlaybackState.idle => 'Connesso',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ExpeditusColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ExpeditusColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.tv_rounded,
                size: 26,
                color: ExpeditusColors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device?.displayName ?? 'Dispositivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: const TextStyle(
                        color: ExpeditusColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: controller.error!),
        ],
        if (controller.firewallRequired) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ExpeditusColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La TV non riesce a contattare il PC. Serve una regola di '
                  'ingresso in Windows Firewall per Expeditus.',
                  style: TextStyle(fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('cast-allow-firewall'),
                  onPressed: controller.firewallBusy ? null : _allowFirewall,
                  icon: controller.firewallBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_outlined, size: 17),
                  label: Text(
                    controller.firewallBusy
                        ? 'Attesa conferma Windows…'
                        : 'Consenti accesso rete',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'I video aperti in Expeditus vengono riprodotti anche sul '
          'dispositivo. L\'audio dell\'app resta disattivato durante la '
          'trasmissione.',
          style: const TextStyle(
            color: ExpeditusColors.muted,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const Key('cast-disconnect'),
              onPressed: _disconnect,
              icon: const Icon(Icons.cast_connected_rounded, size: 17),
              label: const Text('Disconnetti'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscovery() {
    final controller = _controller;
    final error = _connectError ?? controller.discoveryError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dispositivi DLNA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ExpeditusColors.muted,
                ),
              ),
            ),
            IconButton(
              key: const Key('cast-refresh'),
              tooltip: 'Cerca di nuovo',
              onPressed: controller.discovering || _connecting != null
                  ? null
                  : _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        if (controller.discovering) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 10),
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 9),
              Text(
                'Ricerca dispositivi in corso…',
                style: TextStyle(color: ExpeditusColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          _ErrorBox(
            message: error,
            onRetry: _failedDevice != null
                ? () => _connect(_failedDevice!)
                : null,
          ),
        ],
        if (controller.networkProfileRequired) ...[
          const SizedBox(height: 10),
          _NetworkCard(
            busy: controller.networkProfileBusy,
            onFix: _allowPrivateNetworkAndRefresh,
          ),
        ],
        const SizedBox(height: 10),
        _deviceList(controller),
        if (_connecting != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('cast-connecting'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ExpeditusColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aggancio a ${_connecting!.displayName}…',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ExpeditusColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Accendi il dispositivo e assicurati che sia sulla stessa rete '
          'locale del PC. Windows potrebbe chiedere l\'accesso alla rete '
          'la prima volta.',
          style: const TextStyle(
            color: ExpeditusColors.muted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _connecting == null
                  ? () => Navigator.of(context).pop(false)
                  : null,
              child: const Text('Annulla'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _deviceList(CastController controller) {
    if (controller.devices.isEmpty) {
      if (controller.discovering) return const SizedBox(height: 24);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            const Icon(
              Icons.tv_off_rounded,
              size: 34,
              color: ExpeditusColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              controller.hasDiscovered
                  ? 'Nessun dispositivo DLNA trovato.'
                  : 'Nessun dispositivo disponibile.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (controller.hasDiscovered && !controller.discovering) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('cast-retry-discovery'),
                onPressed: _refresh,
                icon: const Icon(Icons.search_rounded, size: 17),
                label: const Text('Cerca di nuovo'),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('cast-allow-firewall-discovery'),
                onPressed: controller.firewallBusy
                    ? null
                    : _allowFirewallAndRefresh,
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: Text(
                  controller.firewallBusy
                      ? 'Attesa conferma Windows…'
                      : 'Consenti accesso rete',
                ),
              ),
              const _TroubleshootingCard(),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final device in controller.devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: ExpeditusColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('cast-device-${device.udn}'),
                borderRadius: BorderRadius.circular(8),
                onTap: controller.discovering || _connecting != null
                    ? null
                    : () => _connect(device),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tv_rounded,
                        size: 21,
                        color: ExpeditusColors.textDim,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (device.modelName.trim().isNotEmpty)
                              Text(
                                device.modelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ExpeditusColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_connecting?.udn == device.udn)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: ExpeditusColors.muted,
                          size: 19,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x22E07A7A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x55E07A7A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: ExpeditusColors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ExpeditusColors.text,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const Key('cast-connect-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
              ),
              child: const Text('Riprova'),
            ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.busy, required this.onFix});

  final bool busy;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExpeditusColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'La rete Windows è impostata come "Pubblica", quindi la ricerca '
            'dei dispositivi DLNA è bloccata. Rendi la rete "Privata" per '
            'trovare la TV.',
            style: TextStyle(fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('cast-allow-private-network'),
            onPressed: busy ? null : onFix,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded, size: 17),
            label: Text(
              busy ? 'Attesa conferma Windows…' : 'Rendi la rete privata',
            ),
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingCard extends StatelessWidget {
  const _TroubleshootingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggerimenti per la ricerca',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: ExpeditusColors.muted,
            ),
          ),
          SizedBox(height: 8),
          _TroubleshootingStep(
            '1',
            'Accendi la TV e verifica che sia collegata alla stessa rete '
            'Wi-Fi o LAN del PC.',
          ),
          _TroubleshootingStep(
            '2',
            'Assicurati che la rete Windows sia "Privata" e non "Pubblica" '
            '(usa il pulsante sopra per correggerla).',
          ),
          _TroubleshootingStep(
            '3',
            'Verifica che sulla TV sia attivo il renderer DLNA (es. '
            '"Condivisione" o "Screen Mirroring").',
          ),
          _TroubleshootingStep(
            '4',
            'Consenti a Expeditus l\'accesso alla rete se Windows Firewall '
            'lo richiede.',
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingStep extends StatelessWidget {
  const _TroubleshootingStep(this.number, this.text);

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ExpeditusColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ExpeditusColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ExpeditusColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
