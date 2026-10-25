// Foto di Benvenuto, Informazioni e Licenze su un telefono 412×915 con i caratteri veri, per guardarle senza
// telefono. Gira solo con `flutter test --update-goldens test/schermate_golden_test.dart` (in CI sul ramo):
// le PNG finiscono in test/goldens/ e la CI le carica come artefatto. Con `flutter test` normale si salta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkacconti/schermate/home.dart' show notaDati, righeBenvenuto;
import 'package:tkacconti/tema.dart';
import 'package:tkacconti/tk_licenza.dart';
import 'package:tkacconti/tk_pro.dart';

import 'caratteri.dart';

const _telefono = Size(412, 915);

Future<void> _mostra(WidgetTester t, Widget schermata, {Size lato = _telefono}) async {
  t.view.physicalSize = lato * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: temaKit(),
      home: schermata));
  await t.pump(const Duration(milliseconds: 300));
  // eventuali immagini (asset) si decodificano solo fuori dal tempo finto del test
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(caricaCaratteri);

  testWidgets('foto delle schermate', skip: !autoUpdateGoldenFiles, (t) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'tk-acconti',
        packageName: 'it.pietrodefilippis.tkacconti',
        version: '2.2.0',
        buildNumber: '28',
        buildSignature: '');
    configTk = configAcconti;
    final lic = Licenza(slug: 'tk-acconti', versione: '2.2.0');
    await t.runAsync(lic.carica);
    proTk = ProTk(lic);
    addTearDown(t.view.reset);

    await _mostra(t, SchermataBenvenuto(lic: lic, righeExtra: const [righeBenvenuto]));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto.png'));

    // con l'interruttore acceso
    // tocco sulla riga (non sul cursore): un solo riconoscitore, l'interruttore cambia una volta sola
    await t.tap(find.text('Invia statistiche anonime di utilizzo'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue, reason: "l'interruttore deve risultare acceso");
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto-statistiche.png'));

    // le stesse righe di datiInformazioni() con un archivio d'esempio
    Future<List<(String, String)>> righe() async => [
          ('Clienti', '34'),
          ('Progetti', '45'),
          ('Acconti', '164'),
          ('Segnalatori', '2'),
          ('Da incassare', '7.310 €'),
          ('Sincronizzazione', 'esempio.it'),
        ];
    await _mostra(t, SchermataInformazioni(righe: righe, notaDati: notaDati));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni.png'));

    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni-fondo.png'));

    // tutta la pagina in una foto sola (telefono «lungo»)
    await _mostra(t, SchermataInformazioni(righe: righe, notaDati: notaDati), lato: const Size(412, 1150));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni-intera.png'));

    await _mostra(t, const SchermataLicenze(versione: '2.2.0'));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/licenze.png'));

    await t.pumpWidget(const SizedBox());
  });
}
