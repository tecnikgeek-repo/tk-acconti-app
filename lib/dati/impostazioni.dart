// Impostazioni di tk-acconti: sito e password della sincronizzazione, PIN, impronta.
// Al primo avvio dopo l'aggiornamento recupera quelle salvate dalla versione Kotlin
// (SharedPreferences «tk_sync» e DataStore «tk_acconti_sicurezza»), così non si deve reinserire niente.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Impostazioni {
  Impostazioni._(this._p, this._sicuro);

  final SharedPreferences _p;
  final FlutterSecureStorage _sicuro;

  String sito = '';
  String password = '';
  String _pinHash = '';

  static Future<Impostazioni> carica({FlutterSecureStorage? sicuro}) async {
    final i = Impostazioni._(await SharedPreferences.getInstance(), sicuro ?? const FlutterSecureStorage());
    if (!(i._p.getBool('migrato') ?? false)) await i._recuperaVecchie();
    i.sito = i._p.getString('sito') ?? '';
    i.password = await i._sicuro.read(key: 'password_sito') ?? '';
    i._pinHash = await i._sicuro.read(key: 'pin_hash') ?? '';
    return i;
  }

  int get syncUltima => _p.getInt('sync_ultima') ?? 0;
  String get syncEsito => _p.getString('sync_esito') ?? '';
  bool get biometria => _p.getBool('biometria') ?? false;
  bool get haPin => _pinHash.isNotEmpty;

  Future<void> salvaSync(String nuovoSito, String nuovaPassword) async {
    var s = nuovoSito.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    sito = s;
    password = nuovaPassword.trim();
    await _p.setString('sito', sito);
    await _sicuro.write(key: 'password_sito', value: password);
  }

  Future<void> salvaEsitoSync(int quando, String esito) async {
    await _p.setInt('sync_ultima', quando);
    await _p.setString('sync_esito', esito);
  }

  // ── PIN: si salva solo l'impronta SHA-256, come prima (il vecchio PIN resta valido) ──

  static String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  bool verificaPin(String pin) => _pinHash.isNotEmpty && _hash(pin) == _pinHash;

  Future<void> salvaPin(String pin) async {
    _pinHash = _hash(pin);
    await _sicuro.write(key: 'pin_hash', value: _pinHash);
  }

  Future<void> rimuoviPin() async {
    _pinHash = '';
    await _sicuro.delete(key: 'pin_hash');
    await _p.setBool('biometria', false);
  }

  Future<void> impostaBiometria(bool si) => _p.setBool('biometria', si);

  // ── recupero dalla versione Kotlin ──

  Future<void> _recuperaVecchie() async {
    try {
      if (Platform.isAndroid) {
        final files = await getApplicationSupportDirectory(); // /data/user/0/<pacchetto>/files
        final cartellaApp = files.parent.path;
        final xml = File('$cartellaApp/shared_prefs/tk_sync.xml');
        if (xml.existsSync()) {
          final v = leggiSharedPreferencesXml(xml.readAsStringSync());
          if ((v['sito'] ?? '').isNotEmpty) await _p.setString('sito', v['sito']!);
          if ((v['password'] ?? '').isNotEmpty) await _sicuro.write(key: 'password_sito', value: v['password']!);
          final ultima = int.tryParse(v['ultima'] ?? '');
          if (ultima != null) await _p.setInt('sync_ultima', ultima);
          if ((v['esito'] ?? '').isNotEmpty) await _p.setString('sync_esito', v['esito']!);
        }
        final pb = File('${files.path}/datastore/tk_acconti_sicurezza.preferences_pb');
        if (pb.existsSync()) {
          final v = leggiDataStore(pb.readAsBytesSync());
          final pin = v['pin_hash'];
          if (pin is String && pin.isNotEmpty) await _sicuro.write(key: 'pin_hash', value: pin);
          if (v['biometria_abilitata'] == true) await _p.setBool('biometria', true);
        }
      }
    } catch (_) {
      // se non si riesce a leggerle si reinseriscono a mano: i dati dei clienti sono nel database
    }
    await _p.setBool('migrato', true);
  }
}

/// Valori di un file SharedPreferences di Android (righe `string`, `long`, `int`, `boolean`).
Map<String, String> leggiSharedPreferencesXml(String xml) {
  String decodifica(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#10;', '\n')
      .replaceAll('&amp;', '&');
  final out = <String, String>{};
  for (final m in RegExp(r'<string name="([^"]*)">([\s\S]*?)</string>').allMatches(xml)) {
    out[decodifica(m.group(1)!)] = decodifica(m.group(2)!);
  }
  for (final m in RegExp(r'<(?:long|int|boolean|float) name="([^"]*)" value="([^"]*)"\s*/>').allMatches(xml)) {
    out[decodifica(m.group(1)!)] = m.group(2)!;
  }
  return out;
}

/// Legge un file Preferences DataStore (protobuf PreferenceMap): chiave → bool / numero / testo.
Map<String, Object?> leggiDataStore(Uint8List dati) {
  var i = 0;
  int varint(Uint8List b) {
    var risultato = 0, scorrimento = 0;
    while (true) {
      final x = b[i++];
      risultato |= (x & 0x7f) << scorrimento;
      if (x & 0x80 == 0) return risultato;
      scorrimento += 7;
    }
  }

  Uint8List pezzo(Uint8List b) {
    final n = varint(b);
    final r = Uint8List.sublistView(b, i, i + n);
    i += n;
    return r;
  }

  void salta(Uint8List b, int tipo) {
    if (tipo == 0) {
      varint(b);
    } else if (tipo == 1) {
      i += 8;
    } else if (tipo == 2) {
      pezzo(b);
    } else if (tipo == 5) {
      i += 4;
    }
  }

  final out = <String, Object?>{};
  while (i < dati.length) {
    final tag = varint(dati);
    if (tag >> 3 == 1 && tag & 7 == 2) {
      final voce = pezzo(dati);
      final salvato = i;
      i = 0;
      String? chiave;
      Object? valore;
      while (i < voce.length) {
        final t = varint(voce);
        if (t >> 3 == 1 && t & 7 == 2) {
          chiave = utf8.decode(pezzo(voce));
        } else if (t >> 3 == 2 && t & 7 == 2) {
          final v = pezzo(voce);
          final dopoValore = i;
          i = 0;
          while (i < v.length) {
            final tv = varint(v);
            final campo = tv >> 3;
            if (campo == 1 && tv & 7 == 0) {
              valore = varint(v) != 0;
            } else if ((campo == 3 || campo == 4) && tv & 7 == 0) {
              valore = varint(v);
            } else if (campo == 5 && tv & 7 == 2) {
              valore = utf8.decode(pezzo(v));
            } else {
              salta(v, tv & 7);
            }
          }
          i = dopoValore;
        } else {
          salta(voce, t & 7);
        }
      }
      i = salvato;
      if (chiave != null) out[chiave] = valore;
    } else {
      salta(dati, tag & 7);
    }
  }
  return out;
}
