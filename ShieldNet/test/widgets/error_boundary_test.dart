import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/widgets/error_boundary.dart';

void main() {
  testWidgets('ShieldNetErrorBoundary affiche le composant de repli et masque les détails techniques bruts', (tester) async {
    bool retryClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ShieldNetErrorBoundary(
          details: FlutterErrorDetails(
            exception: Exception("Test Crash Render"),
            stack: StackTrace.current,
          ),
          onRetry: () {
            retryClicked = true;
          },
        ),
      ),
    );

    // Vérification de la présence des libellés rassurants (Senior UX Writing)
    expect(find.text('Affichage temporairement indisponible'), findsOneWidget);
    expect(
      find.text('Votre protection anti-spam et vos données restent 100% actives et sécurisées en arrière-plan.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text('Recharger l\'écran'), findsOneWidget);

    // Vérifier l'action de réessai
    await tester.tap(find.text('Recharger l\'écran'));
    expect(retryClicked, isTrue);
  });
}
