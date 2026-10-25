// Prove dello strato dati su un database vero (sqflite ffi): schema, migrazione dalla versione Kotlin,
// unione col documento del sito, backup JSON, formati.
// Con i dati veri del sito: ACCONTI_DATI=<file json dell'opzione tk_acconti_data> flutter test
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tkacconti/dati/archivio.dart';
import 'package:tkacconti/dati/database.dart';
import 'package:tkacconti/dati/formati.dart';
import 'package:tkacconti/dati/impostazioni.dart';
import 'package:tkacconti/dati/modelli.dart';

Future<Archivio> nuovo() async {
  final db = await apriDatabase(percorso: inMemoryDatabasePath, fabbrica: databaseFactoryFfiNoIsolate);
  final a = Archivio(db);
  await a.ricarica();
  return a;
}

Map<String, dynamic> esempio() => {
      'clienti': [
        {
          'id': 'c1c1c1c1c1c1c1c1',
          'nome': 'Mario Rossi',
          'nomeWA': 'Mario',
          'telefono': '333 1234567',
          'email': '',
          'note': '',
          'daSaldare': false,
          'updatedAt': 1000,
          'siti': [
            {
              'id': 's1s1s1s1s1s1s1s1',
              'nome': 'Sito vetrina',
              'url': 'rossi.it',
              'totale': 1500,
              'dataInizio': '2026-01-10',
              'dataFine': '',
              'note': '',
              'segnalatoreId': 'g1g1g1g1g1g1g1g1',
              'provvigione': 150,
              'provvigionePagata': false,
              'lavoroFinito': false,
              'provvigionePagataIl': '',
              'updatedAt': 1000,
              'acconti': [
                {'id': 'a1a1a1a1a1a1a1a1', 'importo': 500, 'data': '2026-01-10', 'note': 'anticipo', 'updatedAt': 1000},
                {'id': 'a2a2a2a2a2a2a2a2', 'importo': 1000.5, 'data': '2026-02-01', 'note': '', 'updatedAt': 1000},
              ],
            }
          ],
        }
      ],
      'segnalatori': [
        {'id': 'g1g1g1g1g1g1g1g1', 'nome': 'Luca Bianchi', 'telefono': '3471112222', 'note': '', 'updatedAt': 1000}
      ],
      'eliminati': [],
    };

void main() {
  sqfliteFfiInit();

  test('formati come la versione Kotlin', () {
    expect(euro(44750), '44.750 €');
    expect(euro(1234.56), '1.234,56 €');
    expect(euro(0), '0 €');
    expect(euro(-20), '-20 €');
    expect(leggiImporto('1.234,56'), 1234.56);
    expect(leggiImporto('1234.5'), 1234.5);
    expect(leggiImporto('1500 €'), 1500);
    expect(dataIso(daIso('2026-03-07')), '2026-03-07');
    expect(daIso(''), 0);
    expect(dataBreve(daIso('2026-05-05')), '5 mag 2026');
    expect(perCampo(1500), '1500');
    expect(perCampo(12.5), '12,50');
  });

  test('il sito riempie un telefono vuoto e i conti tornano', () async {
    final a = await nuovo();
    final rimandare = await a.applicaDalSito(jsonEncode({'ok': true, 'dati': esempio()}), adesso());
    expect(rimandare, isFalse);
    expect(a.clienti.length, 1);
    final c = a.clienti.single;
    expect(c.progetti.single.acconti.length, 2);
    expect(c.incassato, 1500.5);
    expect(c.categoria, CategoriaCliente.concluso);
    expect(c.progetti.single.statoProvvigione, StatoProvvigione.lavoroFinito);
    expect(c.progetti.single.progetto.presentatore, 'Luca Bianchi');
    expect(a.segnalatori.single.pronto, 150);
  });

  test('modifiche locali più nuove non vengono sovrascritte e si rimandano', () async {
    final a = await nuovo();
    await a.applicaDalSito(jsonEncode({'dati': esempio()}), adesso());
    final inizio = adesso();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await a.salvaCliente(a.clienti.single.cliente.copia(nome: 'Mario Rossi Srl')); // dopo l'invio
    final rimandare = await a.applicaDalSito(jsonEncode({'dati': esempio()}), inizio);
    expect(rimandare, isTrue);
    expect(a.clienti.single.cliente.nome, 'Mario Rossi Srl');
  });

  test('eliminazioni: traccia per il sito, cascata locale, sparizione dal sito', () async {
    final a = await nuovo();
    await a.applicaDalSito(jsonEncode({'dati': esempio()}), adesso());
    final acc = a.clienti.single.progetti.single.acconti.first;
    await a.eliminaAcconto(acc);
    final doc = jsonDecode(await a.documentoPerSito())['dati'];
    expect((doc['eliminati'] as List).single['id'], acc.uid);
    await a.eliminaCliente(a.clienti.single.cliente);
    expect(await a.db.query('acconti'), isEmpty);
    expect(await a.db.query('progetti'), isEmpty);

    // un cliente che sul sito non c'è più sparisce anche qui
    final b = await nuovo();
    await b.applicaDalSito(jsonEncode({'dati': esempio()}), adesso());
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.applicaDalSito(jsonEncode({'dati': {'clienti': [], 'segnalatori': [], 'eliminati': []}}), adesso());
    expect(b.clienti, isEmpty);
    expect(b.segnalatori, isEmpty);
  });

  test('backup JSON: esporta e reimporta senza perdere niente', () async {
    final a = await nuovo();
    await a.applicaDalSito(jsonEncode({'dati': esempio()}), adesso());
    final json = a.esportaBackup();
    final b = await nuovo();
    expect(await b.importaBackup(json), 1);
    expect(b.clienti.single.incassato, a.clienti.single.incassato);
    expect(b.segnalatori.single.segnalatore.nome, 'Luca Bianchi');
    expect(b.clienti.single.progetti.single.progetto.segnalatoreId, b.segnalatori.single.segnalatore.id);
    // JSON del plugin senza elenco segnalatori: si ricavano da «presentatore»
    final senza = jsonDecode(json) as Map<String, dynamic>..remove('segnalatori');
    final c = await nuovo();
    await c.importaBackup(jsonEncode(senza));
    expect(c.segnalatori.single.segnalatore.nome, 'Luca Bianchi');
    expect(() => c.importaBackup('{"altro": 1}'), throwsA(isA<String>()));
  });

  test('database della versione Kotlin alla 3: migrazione senza perdite', () async {
    final dir = await Directory.systemTemp.createTemp('acconti');
    final percorso = '${dir.path}/tk_acconti.db';
    final vecchio = await databaseFactoryFfiNoIsolate.openDatabase(percorso,
        options: OpenDatabaseOptions(version: 3, onCreate: (db, _) async {
      await db.execute('CREATE TABLE clienti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, nome TEXT NOT NULL, nomeWA TEXT NOT NULL, '
          'telefono TEXT NOT NULL, email TEXT NOT NULL, note TEXT NOT NULL, daSaldare INTEGER NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)');
      await db.execute('CREATE TABLE progetti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, clienteId INTEGER NOT NULL, nome TEXT NOT NULL, '
          'url TEXT NOT NULL, totale REAL NOT NULL, dataInizio INTEGER NOT NULL, dataFine INTEGER NOT NULL, note TEXT NOT NULL, '
          'createdAt INTEGER NOT NULL, presentatore TEXT NOT NULL DEFAULT \'\', presentatoreTel TEXT NOT NULL DEFAULT \'\', '
          'provvigione REAL NOT NULL DEFAULT 0, provvigionePagata INTEGER NOT NULL DEFAULT 0, updatedAt INTEGER NOT NULL DEFAULT 0, '
          'segnalatoreId INTEGER NOT NULL DEFAULT 0, lavoroFinito INTEGER NOT NULL DEFAULT 0, provvigionePagataIl INTEGER NOT NULL DEFAULT 0, '
          'FOREIGN KEY(clienteId) REFERENCES clienti(id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE acconti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, progettoId INTEGER NOT NULL, importo REAL NOT NULL, '
          'data INTEGER NOT NULL, note TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL DEFAULT 0, '
          'FOREIGN KEY(progettoId) REFERENCES progetti(id) ON DELETE CASCADE)');
      await db.execute('CREATE TABLE segnalatori (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, nome TEXT NOT NULL, telefono TEXT NOT NULL, '
          'note TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)');
      await db.insert('clienti', {'nome': 'Anna Verdi', 'nomeWA': 'Anna', 'telefono': '', 'email': '', 'note': '', 'daSaldare': 1, 'createdAt': 1, 'updatedAt': 1});
      await db.insert('progetti', {'clienteId': 1, 'nome': 'Negozio', 'url': '', 'totale': 3000, 'dataInizio': 0, 'dataFine': 0, 'note': '', 'createdAt': 1});
      await db.insert('acconti', {'progettoId': 1, 'importo': 1200, 'data': 5, 'note': '', 'createdAt': 1});
    }));
    await vecchio.close();
    final db = await apriDatabase(percorso: percorso, fabbrica: databaseFactoryFfiNoIsolate);
    final a = Archivio(db);
    await a.ricarica();
    expect(a.clienti.single.cliente.nome, 'Anna Verdi');
    expect(a.clienti.single.cliente.uid.length, 16);
    expect(a.clienti.single.incassato, 1200);
    expect(a.clienti.single.categoria, CategoriaCliente.daSaldare);
    expect(await db.query('eliminati'), isEmpty);
    await db.close();
  });

  test('impostazioni della versione Kotlin: SharedPreferences e DataStore', () {
    final xml = '<?xml version=\'1.0\' encoding=\'utf-8\' standalone=\'yes\' ?>\n<map>\n'
        '    <string name="sito">https://esempio.it</string>\n'
        '    <string name="password">a&amp;b&lt;c</string>\n'
        '    <long name="ultima" value="1760000000000" />\n</map>\n';
    final v = leggiSharedPreferencesXml(xml);
    expect(v['sito'], 'https://esempio.it');
    expect(v['password'], 'a&b<c');
    expect(v['ultima'], '1760000000000');

    // PreferenceMap { "pin_hash": "abc", "biometria_abilitata": true }
    List<int> lungo(int campo, List<int> dati) => [campo << 3 | 2, dati.length, ...dati];
    final pin = lungo(1, [...lungo(1, utf8.encode('pin_hash')), ...lungo(2, lungo(5, utf8.encode('abc')))]);
    final bio = lungo(1, [...lungo(1, utf8.encode('biometria_abilitata')), ...lungo(2, [1 << 3 | 0, 1])]);
    final d = leggiDataStore(Uint8List.fromList([...pin, ...bio]));
    expect(d['pin_hash'], 'abc');
    expect(d['biometria_abilitata'], true);
  });

  final datiVeri = Platform.environment['ACCONTI_DATI'];
  test('dati veri del sito: tutto arriva e i totali coincidono', () async {
    if (datiVeri == null) return markTestSkipped('ACCONTI_DATI non indicato');
    var d = jsonDecode(File(datiVeri).readAsStringSync());
    if (d is String) d = jsonDecode(d);
    final clienti = (d['clienti'] as List).cast<Map>();
    final siti = [for (final c in clienti) ...(c['siti'] as List).cast<Map>()];
    final acconti = [for (final s in siti) ...(s['acconti'] as List).cast<Map>()];
    double num_(Object? v) => v is num ? v.toDouble() : double.parse('$v');
    final a = await nuovo();
    await a.applicaDalSito(jsonEncode({'dati': d}), adesso());
    expect(a.clienti.length, clienti.length);
    expect(a.clienti.fold<int>(0, (s, c) => s + c.progetti.length), siti.length);
    expect(a.clienti.fold<int>(0, (s, c) => s + c.progetti.fold<int>(0, (x, p) => x + p.acconti.length)), acconti.length);
    expect(a.segnalatori.length, (d['segnalatori'] as List).length);
    final totale = siti.fold<double>(0, (s, x) => s + num_(x['totale']));
    final incassato = acconti.fold<double>(0, (s, x) => s + num_(x['importo']));
    expect(a.clienti.fold<double>(0, (s, c) => s + c.totale), closeTo(totale, .001));
    expect(a.clienti.fold<double>(0, (s, c) => s + c.incassato), closeTo(incassato, .001));
    // il documento che partirebbe verso il sito ha gli stessi id
    final doc = jsonDecode(await a.documentoPerSito())['dati'];
    expect({for (final c in doc['clienti']) c['id']}, {for (final c in clienti) c['id']});
    // secondo giro con lo stesso documento: nulla cambia, nulla da rimandare
    final rimandare = await a.applicaDalSito(jsonEncode({'dati': d}), adesso());
    expect(rimandare, isFalse);
    expect(a.clienti.length, clienti.length);
    // backup e reimport
    final b = await nuovo();
    await b.importaBackup(a.esportaBackup());
    expect(b.clienti.fold<double>(0, (s, c) => s + c.incassato), closeTo(incassato, .001));
    // ignore: avoid_print
    print('Dati veri: ${a.clienti.length} clienti, ${siti.length} progetti, ${acconti.length} acconti, '
        'da incassare ${euro(a.clienti.fold<double>(0, (s, c) => s + c.residuo))}');
  });
}
