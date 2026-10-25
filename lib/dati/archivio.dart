// Archivio di tk-acconti: legge tutto in memoria (pochi dati), scrive sul database e avvisa lo schermo.
// Le regole sono quelle della versione Kotlin (AccontiRepository): uid per il sito, tracce delle eliminazioni,
// segnalatori copiati nei progetti, unione col documento del sito.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'formati.dart';
import 'modelli.dart';

class Archivio extends ChangeNotifier {
  Archivio(this.db);

  final Database db;

  List<ClienteCompleto> clienti = const [];
  List<SegnalatoreConProgetti> segnalatori = const [];
  bool pronto = false;

  /// Chiamata a ogni modifica locale: l'app la usa per programmare la sincronizzazione col sito.
  VoidCallback? onModifica;

  // ───────────────────────── lettura ─────────────────────────

  Future<void> ricarica() async {
    final rc = await db.query('clienti');
    final rp = await db.query('progetti');
    final ra = await db.query('acconti');
    final rs = await db.query('segnalatori');
    final accPerProgetto = <int, List<Acconto>>{};
    for (final r in ra) {
      final a = Acconto.daRiga(r);
      accPerProgetto.putIfAbsent(a.progettoId, () => []).add(a);
    }
    final progetti = [for (final r in rp) Progetto.daRiga(r)];
    final pca = {for (final p in progetti) p.id: ProgettoConAcconti(p, accPerProgetto[p.id] ?? [])};
    final perCliente = <int, List<ProgettoConAcconti>>{};
    final perSegnalatore = <int, List<ProgettoConAcconti>>{};
    for (final p in progetti) {
      perCliente.putIfAbsent(p.clienteId, () => []).add(pca[p.id]!);
      if (p.segnalatoreId > 0) perSegnalatore.putIfAbsent(p.segnalatoreId, () => []).add(pca[p.id]!);
    }
    int perNome(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    clienti = [
      for (final r in rc)
        () {
          final c = Cliente.daRiga(r);
          final ps = perCliente[c.id] ?? [];
          ps.sort((a, b) => a.progetto.id.compareTo(b.progetto.id));
          return ClienteCompleto(c, ps);
        }()
    ]..sort((a, b) => perNome(a.cliente.nome, b.cliente.nome));
    segnalatori = [
      for (final r in rs)
        () {
          final s = Segnalatore.daRiga(r);
          return SegnalatoreConProgetti(s, perSegnalatore[s.id] ?? []);
        }()
    ]..sort((a, b) => perNome(a.segnalatore.nome, b.segnalatore.nome));
    pronto = true;
    notifyListeners();
  }

  ClienteCompleto? cliente(int id) {
    for (final c in clienti) {
      if (c.cliente.id == id) return c;
    }
    return null;
  }

  ProgettoConAcconti? progetto(int id) {
    for (final c in clienti) {
      for (final p in c.progetti) {
        if (p.progetto.id == id) return p;
      }
    }
    return null;
  }

  SegnalatoreConProgetti? segnalatore(int id) {
    for (final s in segnalatori) {
      if (s.segnalatore.id == id) return s;
    }
    return null;
  }

  // ───────────────────────── scrittura ─────────────────────────

  Future<void> _fatto() async {
    await ricarica();
    onModifica?.call();
  }

  Future<void> _traccia(DatabaseExecutor e, String tipo, String uid) async {
    if (uid.trim().isNotEmpty) await e.insert('eliminati', {'tipo': tipo, 'uid': uid, 'at': adesso()});
  }

  Future<int> salvaCliente(Cliente c) async {
    final ts = adesso();
    final x = c.uid.isEmpty ? c.copia(uid: nuovoUid()) : c;
    int id;
    if (x.id == 0) {
      id = await db.insert('clienti', x.copia(createdAt: ts, updatedAt: ts).riga());
    } else {
      await db.update('clienti', x.copia(updatedAt: ts).riga(), where: 'id = ?', whereArgs: [x.id]);
      id = x.id;
    }
    await _fatto();
    return id;
  }

  Future<void> cambiaDaSaldare(Cliente c) async {
    await db.update('clienti', {'daSaldare': c.daSaldare ? 0 : 1, 'updatedAt': adesso()},
        where: 'id = ?', whereArgs: [c.id]);
    await _fatto();
  }

  /// Elimina il cliente con progetti e acconti (cascata del database) e lascia la traccia per il sito.
  Future<void> eliminaCliente(Cliente c) async {
    await db.transaction((t) async {
      await t.delete('clienti', where: 'id = ?', whereArgs: [c.id]);
      await _traccia(t, 'cliente', c.uid);
    });
    await _fatto();
  }

  Future<int> salvaProgetto(Progetto progetto) async {
    final ts = adesso();
    // nome e telefono del segnalatore copiati nel progetto (compatibilità col JSON del plugin)
    Segnalatore? s;
    if (progetto.segnalatoreId > 0) {
      final r = await db.query('segnalatori', where: 'id = ?', whereArgs: [progetto.segnalatoreId]);
      if (r.isNotEmpty) s = Segnalatore.daRiga(r.first);
    }
    var p = progetto.copia(
      segnalatoreId: s?.id ?? 0,
      presentatore: s?.nome ?? '',
      presentatoreTel: s?.telefono ?? '',
    );
    if (p.uid.isEmpty) p = p.copia(uid: nuovoUid());
    int id;
    if (p.id == 0) {
      id = await db.insert('progetti', p.copia(createdAt: ts, updatedAt: ts).riga());
    } else {
      await db.update('progetti', p.copia(updatedAt: ts).riga(), where: 'id = ?', whereArgs: [p.id]);
      id = p.id;
    }
    await _fatto();
    return id;
  }

  Future<void> cambiaProvvigionePagata(Progetto p) async {
    final pagata = !p.provvigionePagata;
    await db.update(
        'progetti',
        {
          'provvigionePagata': pagata ? 1 : 0,
          'provvigionePagataIl': pagata ? adesso() : 0,
          'updatedAt': adesso(),
        },
        where: 'id = ?',
        whereArgs: [p.id]);
    await _fatto();
  }

  Future<void> cambiaLavoroFinito(Progetto p) async {
    await db.update('progetti', {'lavoroFinito': p.lavoroFinito ? 0 : 1, 'updatedAt': adesso()},
        where: 'id = ?', whereArgs: [p.id]);
    await _fatto();
  }

  Future<void> eliminaProgetto(Progetto p) async {
    await db.transaction((t) async {
      await t.delete('progetti', where: 'id = ?', whereArgs: [p.id]);
      await _traccia(t, 'sito', p.uid);
    });
    await _fatto();
  }

  Future<int> salvaSegnalatore(Segnalatore segnalatore) async {
    final ts = adesso();
    final s = segnalatore.uid.isEmpty ? segnalatore.copia(uid: nuovoUid()) : segnalatore;
    int id;
    if (s.id == 0) {
      id = await db.insert('segnalatori', s.copia(createdAt: ts, updatedAt: ts).riga());
    } else {
      await db.transaction((t) async {
        await t.update('segnalatori', s.copia(updatedAt: ts).riga(), where: 'id = ?', whereArgs: [s.id]);
        // tiene allineati nome e telefono copiati nei suoi progetti
        await t.update('progetti', {'presentatore': s.nome, 'presentatoreTel': s.telefono},
            where: 'segnalatoreId = ?', whereArgs: [s.id]);
      });
      id = s.id;
    }
    await _fatto();
    return id;
  }

  /// Elimina il segnalatore: i progetti restano, senza segnalatore.
  Future<void> eliminaSegnalatore(Segnalatore s) async {
    await db.transaction((t) async {
      await t.update('progetti', {'segnalatoreId': 0, 'presentatore': '', 'presentatoreTel': '', 'updatedAt': adesso()},
          where: 'segnalatoreId = ?', whereArgs: [s.id]);
      await t.delete('segnalatori', where: 'id = ?', whereArgs: [s.id]);
      await _traccia(t, 'segnalatore', s.uid);
    });
    await _fatto();
  }

  Future<int> salvaAcconto(Acconto acconto) async {
    final ts = adesso();
    final a = acconto.uid.isEmpty ? acconto.copia(uid: nuovoUid()) : acconto;
    int id;
    if (a.id == 0) {
      id = await db.insert('acconti', a.copia(createdAt: ts, updatedAt: ts).riga());
    } else {
      await db.update('acconti', a.copia(updatedAt: ts).riga(), where: 'id = ?', whereArgs: [a.id]);
      id = a.id;
    }
    await _fatto();
    return id;
  }

  Future<void> eliminaAcconto(Acconto a) async {
    await db.transaction((t) async {
      await t.delete('acconti', where: 'id = ?', whereArgs: [a.id]);
      await _traccia(t, 'acconto', a.uid);
    });
    await _fatto();
  }

  // ───────────────────────── backup JSON (compatibile col plugin) ─────────────────────────

  /// { "clienti": [ {id, nome, nomeWA, telefono, email, note, daSaldare, siti: [ {…, acconti: [...]}]}],
  ///   "segnalatori": [ {nome, telefono, note} ] }  — date ISO, id come stringhe.
  String esportaBackup() {
    final out = {
      'clienti': [
        for (final cc in clienti)
          {
            'id': '${cc.cliente.id}',
            'nome': cc.cliente.nome,
            'nomeWA': cc.cliente.nomeWA,
            'telefono': cc.cliente.telefono,
            'email': cc.cliente.email,
            'note': cc.cliente.note,
            'daSaldare': cc.cliente.daSaldare,
            'siti': [
              for (final pc in cc.progetti)
                {
                  'id': '${pc.progetto.id}',
                  'nome': pc.progetto.nome,
                  'url': pc.progetto.url,
                  'totale': pc.progetto.totale,
                  'dataInizio': dataIso(pc.progetto.dataInizio),
                  'dataFine': dataIso(pc.progetto.dataFine),
                  'note': pc.progetto.note,
                  'presentatore': pc.progetto.presentatore,
                  'presentatoreTel': pc.progetto.presentatoreTel,
                  'provvigione': pc.progetto.provvigione,
                  'provvigionePagata': pc.progetto.provvigionePagata,
                  'lavoroFinito': pc.progetto.lavoroFinito,
                  'provvigionePagataIl': dataIso(pc.progetto.provvigionePagataIl),
                  'acconti': [
                    for (final a in pc.acconti)
                      {'id': '${a.id}', 'importo': a.importo, 'data': dataIso(a.data), 'note': a.note}
                  ],
                }
            ],
          }
      ],
      'segnalatori': [
        for (final s in segnalatori)
          {'nome': s.segnalatore.nome, 'telefono': s.segnalatore.telefono, 'note': s.segnalatore.note}
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// Sostituisce TUTTI i dati con quelli del backup. I segnalatori vengono dall'elenco del backup e,
  /// per i JSON del plugin che non lo hanno, dai nomi «presentatore» (stesso nome = stessa scheda).
  /// Restituisce il numero di clienti importati. Lancia un errore se il file non è un backup valido.
  Future<int> importaBackup(String testo) async {
    final radice = jsonDecode(testo);
    if (radice is! Map || radice['clienti'] is! List) throw 'Il file non è un backup di Acconti';
    String s(Object? v) => v == null ? '' : '$v';
    double d(Object? v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    bool b(Object? v) => v == true || v == 1 || v == 'true';
    final clientiJ = (radice['clienti'] as List).whereType<Map>().toList();
    final segnJ = (radice['segnalatori'] is List ? radice['segnalatori'] as List : const []).whereType<Map>();

    await db.transaction((t) async {
      await t.delete('clienti'); // progetti e acconti vanno via a cascata
      await t.delete('segnalatori');
      final ts = adesso();
      final perNome = <String, Segnalatore>{};
      for (final j in segnJ) {
        final nome = s(j['nome']).trim();
        final chiave = nome.toLowerCase();
        if (chiave.isEmpty || perNome.containsKey(chiave)) continue;
        final nuovo = Segnalatore(
            uid: nuovoUid(), nome: nome, telefono: s(j['telefono']).trim(), note: s(j['note']), createdAt: ts, updatedAt: ts);
        perNome[chiave] = nuovo.copia(id: await t.insert('segnalatori', nuovo.riga()));
      }
      for (final jc in clientiJ) {
        final c = Cliente(
          uid: nuovoUid(),
          nome: s(jc['nome']),
          nomeWA: s(jc['nomeWA']),
          telefono: s(jc['telefono']),
          email: s(jc['email']),
          note: s(jc['note']),
          daSaldare: b(jc['daSaldare']),
        );
        final cid = await t.insert('clienti', c.riga());
        for (final js in (jc['siti'] is List ? jc['siti'] as List : const []).whereType<Map>()) {
          final pres = s(js['presentatore']).trim();
          final presTel = s(js['presentatoreTel']).trim();
          Segnalatore? seg;
          if (pres.isNotEmpty) {
            seg = perNome[pres.toLowerCase()];
            if (seg == null) {
              final nuovo = Segnalatore(uid: nuovoUid(), nome: pres, telefono: presTel, createdAt: ts, updatedAt: ts);
              seg = nuovo.copia(id: await t.insert('segnalatori', nuovo.riga()));
              perNome[pres.toLowerCase()] = seg;
            }
          }
          final p = Progetto(
            uid: nuovoUid(),
            clienteId: cid,
            nome: s(js['nome']),
            url: s(js['url']),
            totale: d(js['totale']),
            dataInizio: daIso(s(js['dataInizio'])),
            dataFine: daIso(s(js['dataFine'])),
            note: s(js['note']),
            presentatore: seg?.nome ?? '',
            presentatoreTel: seg == null ? '' : (seg.telefono.isNotEmpty ? seg.telefono : presTel),
            provvigione: d(js['provvigione']),
            provvigionePagata: b(js['provvigionePagata']),
            segnalatoreId: seg?.id ?? 0,
            lavoroFinito: b(js['lavoroFinito']),
            provvigionePagataIl: daIso(s(js['provvigionePagataIl'])),
          );
          final pid = await t.insert('progetti', p.riga());
          for (final ja in (js['acconti'] is List ? js['acconti'] as List : const []).whereType<Map>()) {
            final data = daIso(s(ja['data']));
            await t.insert(
                'acconti',
                Acconto(
                  uid: nuovoUid(),
                  progettoId: pid,
                  importo: d(ja['importo']),
                  data: data > 0 ? data : adesso(),
                  note: s(ja['note']),
                ).riga());
          }
        }
      }
    });
    await _fatto();
    return clientiJ.length;
  }

  // ───────────────────────── sincronizzazione col sito ─────────────────────────

  /// Documento da mandare al sito: { "dati": { clienti, segnalatori, eliminati } } con uid e updatedAt.
  Future<String> documentoPerSito() async {
    final uidSegnalatore = {for (final s in segnalatori) s.segnalatore.id: s.segnalatore.uid};
    final eliminati = await db.query('eliminati');
    final dati = {
      'clienti': [
        for (final cc in [...clienti]..sort((a, b) => a.cliente.id.compareTo(b.cliente.id)))
          {
            'id': cc.cliente.uid,
            'nome': cc.cliente.nome,
            'nomeWA': cc.cliente.nomeWA,
            'telefono': cc.cliente.telefono,
            'email': cc.cliente.email,
            'note': cc.cliente.note,
            'daSaldare': cc.cliente.daSaldare,
            'updatedAt': cc.cliente.updatedAt,
            'siti': [
              for (final pc in cc.progetti)
                {
                  'id': pc.progetto.uid,
                  'nome': pc.progetto.nome,
                  'url': pc.progetto.url,
                  'totale': pc.progetto.totale,
                  'dataInizio': dataIso(pc.progetto.dataInizio),
                  'dataFine': dataIso(pc.progetto.dataFine),
                  'note': pc.progetto.note,
                  'segnalatoreId': uidSegnalatore[pc.progetto.segnalatoreId] ?? '',
                  'presentatore': pc.progetto.presentatore,
                  'presentatoreTel': pc.progetto.presentatoreTel,
                  'provvigione': pc.progetto.provvigione,
                  'provvigionePagata': pc.progetto.provvigionePagata,
                  'lavoroFinito': pc.progetto.lavoroFinito,
                  'provvigionePagataIl': dataIso(pc.progetto.provvigionePagataIl),
                  'updatedAt': pc.progetto.updatedAt,
                  'acconti': [
                    for (final a in pc.acconti)
                      {
                        'id': a.uid,
                        'importo': a.importo,
                        'data': dataIso(a.data),
                        'note': a.note,
                        'updatedAt': a.updatedAt,
                      }
                  ],
                }
            ],
          }
      ],
      'segnalatori': [
        for (final s in segnalatori)
          {
            'id': s.segnalatore.uid,
            'nome': s.segnalatore.nome,
            'telefono': s.segnalatore.telefono,
            'note': s.segnalatore.note,
            'updatedAt': s.segnalatore.updatedAt,
          }
      ],
      'eliminati': [
        for (final e in eliminati) {'tipo': e['tipo'], 'id': e['uid'], 'at': e['at']}
      ],
    };
    return jsonEncode({'dati': dati});
  }

  /// Applica il documento unito restituito dal sito. [inizio] è quando è partita la sincronizzazione:
  /// ciò che sul telefono è stato modificato o eliminato DOPO non viene toccato (partirà al giro dopo).
  /// Restituisce true se è rimasto qualcosa da rimandare.
  Future<bool> applicaDalSito(String risposta, int inizio) async {
    final radice = jsonDecode(risposta);
    final Map d = (radice is Map && radice['dati'] is Map) ? radice['dati'] as Map : (radice as Map);
    String s(Object? v) => v == null ? '' : '$v';
    double n(Object? v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
    int i(Object? v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
    bool b(Object? v) => v == true || v == 1 || v == 'true';
    List<Map> lista(Object? v) => v is List ? v.whereType<Map>().toList() : const [];

    final clientiR = lista(d['clienti']);
    final segnR = lista(d['segnalatori']);
    var daRimandare = false;
    final ora = adesso();

    await db.transaction((t) async {
      final tracce = <String, int>{};
      for (final e in await t.query('eliminati')) {
        final k = '${e['tipo']}:${e['uid']}';
        final at = i(e['at']);
        if (at > (tracce[k] ?? 0)) tracce[k] = at;
      }
      bool eliminatoDopo(String tipo, String uid) => (tracce['$tipo:$uid'] ?? 0) > inizio;

      // segnalatori
      Future<Map<String, Segnalatore>> segLocali() async =>
          {for (final r in await t.query('segnalatori')) s(r['uid']): Segnalatore.daRiga(r)};
      var locSeg = await segLocali();
      for (final js in segnR) {
        final uid = s(js['id']);
        if (uid.trim().isEmpty) continue;
        if (eliminatoDopo('segnalatore', uid)) {
          daRimandare = true;
          continue;
        }
        final l = locSeg[uid];
        final up = i(js['updatedAt']);
        if (l == null) {
          await t.insert(
              'segnalatori',
              Segnalatore(
                      uid: uid,
                      nome: s(js['nome']),
                      telefono: s(js['telefono']),
                      note: s(js['note']),
                      createdAt: ora,
                      updatedAt: up)
                  .riga());
        } else if (up >= l.updatedAt) {
          await t.update('segnalatori', {'nome': s(js['nome']), 'telefono': s(js['telefono']), 'note': s(js['note']), 'updatedAt': up},
              where: 'id = ?', whereArgs: [l.id]);
        } else {
          daRimandare = true;
        }
      }
      final uidSegRemoti = {for (final js in segnR) s(js['id'])};
      for (final l in locSeg.values) {
        if (!uidSegRemoti.contains(l.uid) && l.updatedAt <= inizio) {
          await t.delete('segnalatori', where: 'id = ?', whereArgs: [l.id]);
        }
      }
      locSeg = await segLocali();

      // clienti
      final locClienti = {for (final r in await t.query('clienti')) s(r['uid']): Cliente.daRiga(r)};
      final idCliente = <String, int>{};
      for (final jc in clientiR) {
        final uid = s(jc['id']);
        if (uid.trim().isEmpty) continue;
        if (eliminatoDopo('cliente', uid)) {
          daRimandare = true;
          continue;
        }
        final l = locClienti[uid];
        final up = i(jc['updatedAt']);
        final valori = {
          'nome': s(jc['nome']),
          'nomeWA': s(jc['nomeWA']),
          'telefono': s(jc['telefono']),
          'email': s(jc['email']),
          'note': s(jc['note']),
          'daSaldare': b(jc['daSaldare']) ? 1 : 0,
          'updatedAt': up,
        };
        if (l == null) {
          idCliente[uid] = await t.insert('clienti', {...valori, 'uid': uid, 'createdAt': ora});
        } else if (up >= l.updatedAt) {
          await t.update('clienti', valori, where: 'id = ?', whereArgs: [l.id]);
          idCliente[uid] = l.id;
        } else {
          daRimandare = true;
          idCliente[uid] = l.id;
        }
      }

      // progetti (sul sito si chiamano «siti»)
      final locProgetti = {for (final r in await t.query('progetti')) s(r['uid']): Progetto.daRiga(r)};
      final idProgetto = <String, int>{};
      for (final jc in clientiR) {
        final clienteId = idCliente[s(jc['id'])];
        if (clienteId == null) continue;
        for (final js in lista(jc['siti'])) {
          final uid = s(js['id']);
          if (uid.trim().isEmpty) continue;
          if (eliminatoDopo('sito', uid)) {
            daRimandare = true;
            continue;
          }
          final seg = locSeg[s(js['segnalatoreId'])];
          final up = i(js['updatedAt']);
          final valori = {
            'clienteId': clienteId,
            'nome': s(js['nome']),
            'url': s(js['url']),
            'totale': n(js['totale']),
            'dataInizio': daIso(s(js['dataInizio'])),
            'dataFine': daIso(s(js['dataFine'])),
            'note': s(js['note']),
            'presentatore': seg?.nome ?? '',
            'presentatoreTel': seg?.telefono ?? '',
            'provvigione': n(js['provvigione']),
            'provvigionePagata': b(js['provvigionePagata']) ? 1 : 0,
            'segnalatoreId': seg?.id ?? 0,
            'lavoroFinito': b(js['lavoroFinito']) ? 1 : 0,
            'provvigionePagataIl': daIso(s(js['provvigionePagataIl'])),
            'updatedAt': up,
          };
          final l = locProgetti[uid];
          if (l == null) {
            idProgetto[uid] = await t.insert('progetti', {...valori, 'uid': uid, 'createdAt': ora});
          } else if (up >= l.updatedAt) {
            await t.update('progetti', valori, where: 'id = ?', whereArgs: [l.id]);
            idProgetto[uid] = l.id;
          } else {
            daRimandare = true;
            idProgetto[uid] = l.id;
          }
        }
      }

      // acconti
      final locAcconti = {for (final r in await t.query('acconti')) s(r['uid']): Acconto.daRiga(r)};
      final uidAccontiRemoti = <String>{};
      for (final jc in clientiR) {
        for (final js in lista(jc['siti'])) {
          final progettoId = idProgetto[s(js['id'])];
          for (final ja in lista(js['acconti'])) {
            uidAccontiRemoti.add(s(ja['id']));
            if (progettoId == null) continue;
            final uid = s(ja['id']);
            if (uid.trim().isEmpty) continue;
            if (eliminatoDopo('acconto', uid)) {
              daRimandare = true;
              continue;
            }
            final up = i(ja['updatedAt']);
            final valori = {
              'progettoId': progettoId,
              'importo': n(ja['importo']),
              'data': daIso(s(ja['data'])),
              'note': s(ja['note']),
              'updatedAt': up,
            };
            final l = locAcconti[uid];
            if (l == null) {
              await t.insert('acconti', {...valori, 'uid': uid, 'createdAt': ora});
            } else if (up >= l.updatedAt) {
              await t.update('acconti', valori, where: 'id = ?', whereArgs: [l.id]);
            } else {
              daRimandare = true;
            }
          }
        }
      }

      // record che sul sito non ci sono più (e che qui non sono stati toccati dopo l'invio)
      for (final r in await t.query('acconti')) {
        final a = Acconto.daRiga(r);
        if (!uidAccontiRemoti.contains(a.uid) && a.updatedAt <= inizio) {
          await t.delete('acconti', where: 'id = ?', whereArgs: [a.id]);
        }
      }
      final uidSitiRemoti = {for (final jc in clientiR) for (final js in lista(jc['siti'])) s(js['id'])};
      for (final r in await t.query('progetti')) {
        final p = Progetto.daRiga(r);
        if (!uidSitiRemoti.contains(p.uid) && p.updatedAt <= inizio) {
          await t.delete('progetti', where: 'id = ?', whereArgs: [p.id]);
        }
      }
      final uidClientiRemoti = {for (final jc in clientiR) s(jc['id'])};
      for (final r in await t.query('clienti')) {
        final c = Cliente.daRiga(r);
        if (!uidClientiRemoti.contains(c.uid) && c.updatedAt <= inizio) {
          await t.delete('clienti', where: 'id = ?', whereArgs: [c.id]);
        }
      }

      // progetti che puntano a un segnalatore che non c'è più
      await t.execute("UPDATE progetti SET segnalatoreId = 0, presentatore = '', presentatoreTel = '' "
          'WHERE segnalatoreId <> 0 AND segnalatoreId NOT IN (SELECT id FROM segnalatori)');
      // le tracce già inviate le conserva il sito
      await t.delete('eliminati', where: 'at <= ?', whereArgs: [inizio]);
    });
    await ricarica();
    return daRimandare;
  }
}
