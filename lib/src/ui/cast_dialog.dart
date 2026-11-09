import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../services/dlna/dlna_models.dart';
import '../state/cast_controller.dart';
import '../theme.dart';
import '../util/cast_error_text.dart';
import '../util/l10n.dart';
import '../util/platform.dart';

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
      final failure = _controller.error;
      _connectError = failure == null
          ? context.l10n.castConnectFailed
          : castFailureText(context.l10n, failure);
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
      final failure = _controller.error;
      setState(
        () => _connectError = failure == null
            ? context.l10n.castConnectFailed
            : castFailureText(context.l10n, failure),
      );
      return;
    }
    await _controller.discover(force: true);
  }

  Future<void> _allowPrivateNetworkAndRefresh() async {
    final fixed = await _controller.allowPrivateNetwork();
    if (!mounted) return;
    if (!fixed) {
      final failure = _controller.error;
      setState(
        () => _connectError = failure == null
            ? context.l10n.castConnectFailed
            : castFailureText(context.l10n, failure),
      );
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
                        Expanded(
                          child: Text(
                            context.l10n.castTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.close,
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
    final l10n = context.l10n;
    final controller = _controller;
    final device = controller.device;
    final status = switch (controller.playback) {
      CastPlaybackState.starting => l10n.castStatusStarting,
      CastPlaybackState.playing => l10n.castStatusPlaying,
      CastPlaybackState.paused => l10n.castStatusPaused,
      CastPlaybackState.stopped => l10n.castStatusStopped,
      CastPlaybackState.error => l10n.castStatusError,
      CastPlaybackState.idle => l10n.castStatusIdle,
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
                      _deviceLabel(device, l10n),
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
          _ErrorBox(message: castFailureText(l10n, controller.error!)),
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
                Text(
                  l10n.castFirewallWarning,
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
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
                        ? l10n.castWaitingWindows
                        : l10n.castAllowNetwork,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.castExplanation,
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
              label: Text(l10n.disconnect),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.close),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscovery() {
    final l10n = context.l10n;
    final controller = _controller;
    final failure = controller.discoveryError;
    final error =
        _connectError ??
        (failure == null ? null : castFailureText(l10n, failure));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.castDlnaDevices,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ExpeditusColors.muted,
                ),
              ),
            ),
            IconButton(
              key: const Key('cast-refresh'),
              tooltip: l10n.castSearchAgain,
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
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 9),
              Text(
                l10n.castSearching,
                style: const TextStyle(
                  color: ExpeditusColors.muted,
                  fontSize: 12,
                ),
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
                    l10n.castConnecting(_deviceLabel(_connecting, l10n)),
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
          isMobilePlatform
              ? l10n.castDiscoveryHintPhone
              : l10n.castDiscoveryHintDesktop,
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
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ],
    );
  }

  static String _deviceLabel(DlnaDevice? device, AppLocalizations l10n) {
    final name = device?.displayName.trim();
    return name == null || name.isEmpty ? l10n.deviceFallback : name;
  }

  Widget _deviceList(CastController controller) {
    final l10n = context.l10n;
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
                  ? l10n.castNoDevicesFound
                  : l10n.castNoDevicesAvailable,
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
                label: Text(l10n.castSearchAgain),
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
                      ? l10n.castWaitingWindows
                      : l10n.castAllowNetwork,
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
                              _deviceLabel(device, l10n),
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
    final l10n = context.l10n;
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
              child: Text(l10n.retry),
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
    final l10n = context.l10n;
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
          Text(
            l10n.castNetworkPublicWarning,
            style: const TextStyle(fontSize: 11.5, height: 1.4),
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
              busy ? l10n.castWaitingWindows : l10n.castMakeNetworkPrivate,
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
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ExpeditusColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.castTroubleshootingTitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: ExpeditusColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          _TroubleshootingStep('1', l10n.castTroubleshootingStep1),
          _TroubleshootingStep('2', l10n.castTroubleshootingStep2),
          _TroubleshootingStep('3', l10n.castTroubleshootingStep3),
          _TroubleshootingStep('4', l10n.castTroubleshootingStep4),
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
