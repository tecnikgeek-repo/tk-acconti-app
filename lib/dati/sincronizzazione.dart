// Sincronizzazione bidirezionale col sito (plugin tk-acconti 1.5.0+): manda tutto il telefono,
// il sito unisce i due archivi (vince la modifica più recente) e restituisce il risultato.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'archivio.dart';
import 'impostazioni.dart';
import 'modelli.dart';

class Sincronizzazione extends ChangeNotifier {
  Sincronizzazione(this.archivio, this.impostazioni);

  final Archivio archivio;
  final Impostazioni impostazioni;

  bool inCorso = false;
  bool ultimaOk = true;
  Timer? _programmata;
  Future<String>? _attuale;

  int get ultima => impostazioni.syncUltima;
  String get esito => impostazioni.syncEsito;
  bool get configurata => impostazioni.sito.isNotEmpty && impostazioni.password.isNotEmpty;

  /// Sincronizza tra poco (raggruppa le modifiche ravvicinate).
  void pianifica([Duration ritardo = const Duration(milliseconds: 2500)]) {
    if (!configurata) return;
    _programmata?.cancel();
    _programmata = Timer(ritardo, sincronizza);
  }

  /// Sincronizza adesso, se sono passati almeno 30 secondi dall'ultima volta.
  void sincronizzaSeServe() {
    if (!configurata) return;
    if (adesso() - ultima < 30000) return;
    sincronizza();
  }

  /// Sincronizzazione completa; restituisce il messaggio d'esito. Una alla volta.
  Future<String> sincronizza() {
    final c = _attuale;
    if (c != null) return c.then((_) => _giro());
    return _attuale = _giro().whenComplete(() => _attuale = null);
  }

  Future<String> _giro() async {
    if (!configurata) return 'Sincronizzazione non configurata';
    inCorso = true;
    notifyListeners();
    final inizio = adesso();
    String messaggio;
    try {
      final corpo = await archivio.documentoPerSito();
      final risposta = await http
          .post(Uri.parse('${_base()}/wp-json/tk-acconti/v1/sync'),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
                'X-TK-Password': impostazioni.password,
              },
              body: corpo)
          .timeout(const Duration(seconds: 45));
      if (risposta.statusCode == 401 || risposta.statusCode == 403) throw 'Password del sito errata';
      if (risposta.statusCode == 404) throw 'Indirizzo sbagliato o plugin da aggiornare (serve la 1.5.0)';
      if (risposta.statusCode != 200) throw 'Il sito ha risposto ${risposta.statusCode}';
      final daRimandare = await archivio.applicaDalSito(risposta.body, inizio);
      if (daRimandare) pianifica(const Duration(seconds: 4));
      messaggio = 'Sincronizzato (${archivio.clienti.length} clienti)';
      ultimaOk = true;
    } on TimeoutException {
      messaggio = 'Il sito non risponde';
      ultimaOk = false;
    } catch (e) {
      messaggio = '$e'.replaceFirst('Exception: ', '').replaceFirst('ClientException: ', '');
      if (messaggio.contains('SocketException') || messaggio.contains('Failed host lookup')) messaggio = 'Nessuna connessione';
      ultimaOk = false;
    }
    await impostazioni.salvaEsitoSync(adesso(), messaggio);
    inCorso = false;
    notifyListeners();
    return messaggio;
  }

  String _base() {
    var s = impostazioni.sito.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    return s;
  }
}
