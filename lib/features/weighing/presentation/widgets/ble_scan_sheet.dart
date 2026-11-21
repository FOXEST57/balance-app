import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/scale_service.dart';

/// Feuille modale de recherche et d'appairage de la balance.
///
/// Permet :
///  - de filtrer sur les balances probables ou d'afficher **tous** les
///    périphériques BLE (sélection manuelle) ;
///  - de voir le RSSI et le poids éventuellement diffusé en clair ;
///  - de se connecter d'un simple tap.
Future<void> showBleScanSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => const _BleScanSheet(),
  );
}

class _BleScanSheet extends ConsumerStatefulWidget {
  const _BleScanSheet();

  @override
  ConsumerState<_BleScanSheet> createState() => _BleScanSheetState();
}

class _BleScanSheetState extends ConsumerState<_BleScanSheet> {
  late final ScaleService _scaleService;
  late final WeighingNotifier _notifier;
  StreamSubscription<Map<String, DiscoveredScale>>? _resultsSubscription;
  StreamSubscription<ScaleConnectionStatus>? _statusSubscription;

  Map<String, DiscoveredScale> _discovered = const <String, DiscoveredScale>{};
  ScaleConnectionStatus _status = ScaleConnectionStatus.idle;
  String? _scanError;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _scaleService = ref.read(scaleServiceProvider);
    _notifier = ref.read(weighingProvider.notifier);
    _discovered = _scaleService.discoveredScales;
    _status = _scaleService.currentStatus;
    _scanError = _scaleService.lastScanError;
    _resultsSubscription = _scaleService.scanResults.listen((
      Map<String, DiscoveredScale> results,
    ) {
      if (!mounted) return;
      setState(() => _discovered = results);
    });
    _statusSubscription = _scaleService.status.listen((
      ScaleConnectionStatus status,
    ) {
      if (!mounted) return;
      setState(() {
        _status = status;
        _scanError = _scaleService.lastScanError;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_notifier.startScan(showAll: _showAll));
    });
  }

  @override
  void dispose() {
    unawaited(_resultsSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_notifier.stopScan());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DiscoveredScale> devices = _discovered.values.toList()
      ..sort(
        (DiscoveredScale a, DiscoveredScale b) => b.rssi.compareTo(a.rssi),
      );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.bluetooth_searching_rounded,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connexion à la balance',
                      style: AppTheme.numeric(16, weight: FontWeight.w600),
                    ),
                  ),
                  if (_status == ScaleConnectionStatus.scanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _showAll,
                activeThumbColor: AppColors.cyan,
                title: const Text(
                  'Afficher tous les appareils BLE',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                subtitle: const Text(
                  'Utile si votre balance n\'apparaît pas dans la liste filtrée.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                onChanged: (bool v) {
                  setState(() => _showAll = v);
                  unawaited(_notifier.startScan(showAll: v));
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.bluetooth_disabled_rounded,
                              size: 40,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              _scanError ??
                                  'Aucun appareil détecté.\nVérifiez que la balance est allumée\net à proximité du téléphone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) => Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) {
                        final DiscoveredScale d = devices[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (d.isLikelyScale
                                        ? AppColors.cyan
                                        : AppColors.textMuted)
                                    .withValues(alpha: 0.15),
                            child: Icon(
                              d.isLikelyScale
                                  ? Icons.monitor_weight_rounded
                                  : Icons.bluetooth_rounded,
                              color: d.isLikelyScale
                                  ? AppColors.cyan
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            d.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '${d.remoteId}  •  RSSI ${d.rssi} dBm'
                            '${d.liveWeightKg != null ? '  •  ${d.liveWeightKg!.toStringAsFixed(2)} kg' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await _notifier.connect(d);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
