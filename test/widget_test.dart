import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';
import 'package:smart_pulchowk/core/services/favorites_provider.dart';
import 'package:smart_pulchowk/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();
    final favoritesProvider = FavoritesProvider();
    await tester.pumpWidget(
      SmartPulchowkApp(
        themeProvider: themeProvider,
        favoritesProvider: favoritesProvider,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Verify initial login screen content is shown.
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
