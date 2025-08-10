import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puffpoint/app.dart';
import 'package:puffpoint/features/spots/repo/spots_repository.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spotsStreamProvider.overrideWith((ref) => const Stream.empty()),
          seedSpotsProvider.overrideWithValue(() async {}),
          createSpotProvider.overrideWithValue(({required title, required description, required coords, String? address, required legalStatus, List<Map<String, String>>? timeWindows, List<String>? tags}) async {}),
        ],
        child: const PuffPointApp(),
      ),
    );
    expect(find.text('puffpoint'), findsOneWidget);
  });
}
