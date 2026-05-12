import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fork_scale/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ForkScaleApp()));
    // Camera initialisation is async; one frame is enough to confirm the
    // widget tree builds without throwing.
    await tester.pump();
  });
}
