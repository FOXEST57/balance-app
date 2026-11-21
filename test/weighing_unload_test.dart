import 'dart:async';

import 'package:balance/core/providers.dart';
import 'package:balance/features/weighing/application/scale_service.dart';
import 'package:balance/features/weighing/domain/entities/scale_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScaleService extends ScaleService {
  final StreamController<ScaleFrame> _frames =
      StreamController<ScaleFrame>.broadcast();
  final StreamController<ScaleConnectionStatus> _statuses =
      StreamController<ScaleConnectionStatus>.broadcast();
  final StreamController<Map<String, DiscoveredScale>> _scans =
      StreamController<Map<String, DiscoveredScale>>.broadcast();

  @override
  Stream<ScaleFrame> get frames => _frames.stream;

  @override
  Stream<ScaleConnectionStatus> get status => _statuses.stream;

  @override
  Stream<Map<String, DiscoveredScale>> get scanResults => _scans.stream;

  void emit(ScaleFrame frame) => _frames.add(frame);

  @override
  Future<void> dispose() async {
    await _frames.close();
    await _statuses.close();
    await _scans.close();
  }
}

void main() {
  test('unloading clears live weight without saving a measurement', () async {
    final _FakeScaleService service = _FakeScaleService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[scaleServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);
    final ProviderSubscription<WeighingState> subscription = container.listen(
      weighingProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    service.emit(
      const ScaleFrame(
        weightKg: 15.87,
        stabilized: false,
        impedanceOhm: 512,
        rawHex: 'AC 27 ... D5',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(weighingProvider).liveWeightKg, 15.87);

    service.emit(
      const ScaleFrame(
        weightKg: 0,
        stabilized: false,
        isUnloaded: true,
        rawHex: 'AC 27 ... D5',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final WeighingState state = container.read(weighingProvider);
    expect(state.liveWeightKg, 0);
    expect(state.liveImpedanceOhm, isNull);
    expect(state.stabilized, isFalse);
    expect(state.lastSaved, isNull);
  });
}
