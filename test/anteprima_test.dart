// Anteprime delle schermate (caratteri veri) in build/anteprime/, per controllarle senza telefono.
// Con i dati veri: ACCONTI_DATI=<json dell'opzione tk_acconti_data> flutter test test/anteprima_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tkacconti/app.dart';
import 'package:tkacconti/dati/archivio.dart';
import 'package:tkacconti/dati/database.dart';
import 'package:tkacconti/dati/impostazioni.dart';
import 'package:tkacconti/dati/modelli.dart';
import 'package:tkacconti/dati/sincronizzazione.dart';
import 'package:tkacconti/schermate/cliente.dart';
import 'package:tkacconti/schermate/home.dart';
import 'package:tkacconti/schermate/impostazioni.dart';
import 'package:tkacconti/schermate/progetto.dart';
import 'package:tkacconti/schermate/segnalatori.dart';
import 'package:tkacconti/tema.dart';

import 'caratteri.dart';
import 'dati_test.dart' show esempio;

class _Sicuro extends FlutterSecureStorage {
  const _Sicuro();
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
          WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async =>
      null;
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions,
      LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {}
}

Future<void> _scatta(WidgetTester t, Widget w, String nome) async {
  final k = GlobalKey();
  await t.pumpWidget(RepaintBoundary(
    key: k,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaKit(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: w,
    ),
  ));
  await t.pump(const Duration(seconds: 1));
  await t.runAsync(() async {
    final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/anteprime').createSync(recursive: true);
    File('build/anteprime/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    configTk = configAcconti;
    SharedPreferences.setMockInitialValues({'migrato': true});
    impostazioni = await Impostazioni.carica(sicuro: const _Sicuro());
    archivio = Archivio(await apriDatabase(percorso: inMemoryDatabasePath, fabbrica: databaseFactoryFfiNoIsolate));
    final f = Platform.environment['ACCONTI_DATI'];
    var d = f == null ? esempio() : jsonDecode(File(f).readAsStringSync());
    if (d is String) d = jsonDecode(d);
    await archivio.applicaDalSito(jsonEncode({'dati': d}), adesso());
    sincronizzazione = Sincronizzazione(archivio, impostazioni);
    await caricaCaratteri();
  });

  testWidgets('anteprime', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    await _scatta(t, const SchermataHome(), 'home');
    // il cliente con più progetti, e il suo progetto con più acconti
    final cc = [...archivio.clienti]..sort((a, b) => b.progetti.length.compareTo(a.progetti.length));
    await _scatta(t, SchermataCliente(cc.first.cliente.id), 'cliente');
    final pc = ([for (final c in archivio.clienti) ...c.progetti]
          ..sort((a, b) => (b.progetto.segnalatoreId > 0 ? 1000 : 0) + b.acconti.length -
              (a.progetto.segnalatoreId > 0 ? 1000 : 0) - a.acconti.length))
        .first;
    await _scatta(t, SchermataProgetto(pc.progetto.id), 'progetto');
    await _scatta(t, const SchermataSegnalatori(), 'segnalatori');
    if (archivio.segnalatori.isNotEmpty) {
      await _scatta(t, SchermataSegnalatore(archivio.segnalatori.first.segnalatore.id), 'segnalatore');
    }
    await _scatta(t, SchermataModificaProgetto(clienteId: pc.progetto.clienteId, progetto: pc.progetto), 'modifica-progetto');
    await _scatta(t, const SchermataImpostazioni(), 'impostazioni');
    await _scatta(t, const SchermataAvvio(), 'avvio');
  });
}
