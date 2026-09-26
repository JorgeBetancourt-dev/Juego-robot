import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/app/screens/home_screen.dart';
import 'package:game_final/domain/progression/game_progress.dart';
import 'package:game_final/domain/session/game_session.dart';

void main() {
  testWidgets('muestra el acceso separado al modo multijugador', (
    tester,
  ) async {
    final session = GameSession.temporary(progress: const GameProgress());

    await tester.pumpWidget(MaterialApp(home: HomeScreen(session: session)));

    expect(find.text('MODO MULTIJUGADOR'), findsOneWidget);
    expect(find.text('NUEVA PARTIDA'), findsOneWidget);
  });
}
