import 'package:balance/core/providers.dart';
import 'package:balance/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWeighingNotifier extends WeighingNotifier {
  @override
  WeighingState build() => const WeighingState();
}

void main() {
  testWidgets('dashboard renders its sliver children without duplicate nodes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          weighingProvider.overrideWith(_FakeWeighingNotifier.new),
          latestMeasurementProvider.overrideWith((Ref ref) => null),
        ],
        child: MaterialApp(
          home: Scaffold(body: DashboardPage(onOpenActivity: () {})),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pesée en direct'), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });
}
