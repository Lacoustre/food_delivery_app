import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:african_cuisine/widgets/meal_image.dart';

/// Meal photos arrive as Supabase Storage URLs, but the app still falls back to
/// bundled assets and to the logo. Two render sites got that branch wrong in
/// opposite directions — one called Image.asset on a URL, the other
/// Image.network on an asset path — and neither showed a symptom until real
/// photos landed, because every meal's image_url was empty.
///
/// These lock the branch down so it can't drift back.
void main() {
  Future<void> pump(WidgetTester tester, String? source) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MealImage(source, width: 50, height: 50)),
      ),
    );
  }

  group('MealImage picks the right loader', () {
    testWidgets('a remote URL renders over the network', (tester) async {
      await pump(tester, 'https://example.supabase.co/storage/v1/jollof.png');

      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('an http (not https) URL is still treated as remote',
        (tester) async {
      await pump(tester, 'http://example.com/waakye.png');

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('a full asset path loads from the bundle', (tester) async {
      await pump(tester, 'assets/images/jollof.png');

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/images/jollof.png');
    });

    testWidgets('a bare filename resolves under assets/images/',
        (tester) async {
      await pump(tester, 'banku.png');

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/banku.png');
    });
  });

  group('MealImage falls back to the logo', () {
    testWidgets('when the source is null', (tester) async {
      await pump(tester, null);

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
    });

    testWidgets('when the source is empty', (tester) async {
      await pump(tester, '');

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
    });

    testWidgets('when the source is only whitespace', (tester) async {
      await pump(tester, '   ');

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
    });
  });

  testWidgets('the requested size is applied', (tester) async {
    await pump(tester, 'assets/images/jollof.png');

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 50);
    expect(image.height, 50);
    expect(image.fit, BoxFit.cover);
  });
}
