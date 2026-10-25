// Schermata principale: quanto c'è da incassare, segnalatori, clienti con filtri e ricerca.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../dati/formati.dart';
import '../dati/modelli.dart';
import '../tema.dart';
import '../tk_pro.dart';
import 'cliente.dart';
import 'impostazioni.dart';
import 'segnalatori.dart';

enum _Filtro {
  tutti('Tutti'),
  inCorso('In corso'),
  daSaldare('Da saldare'),
  conclusi('Conclusi');

  const _Filtro(this.etichetta);
  final String etichetta;
}

Future<T?> vai<T>(BuildContext context, Widget schermata) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => schermata));

class SchermataHome extends StatefulWidget {
  const SchermataHome({super.key, this.crash});

  final String? crash;

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> {
  _Filtro _filtro = _Filtro.inCorso;
  bool _cercando = false;
  String _cerca = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // primo avvio: benvenuto (software libero, privacy, statistiche) PRIMA di qualunque chiamata in rete
      await benvenutoTk(context, righeExtra: const [righeBenvenuto]);
      if (!mounted) return;
      if (widget.crash != null) await _mostraCrash(widget.crash!);
      sincronizzazione.sincronizzaSeServe();
      if (mounted) proponiAggiornamento(context, avvisaSeAggiornata: false);
      // invito al caffè: al primo avvio e poi al massimo una volta al mese, mai sopra un'altra finestra
      if (mounted) invitoCaffe(context);
    });
  }

  Future<void> _mostraCrash(String testo) => showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text("L'app si era chiusa per un errore"),
          content: SingleChildScrollView(
              child: Text(testo, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: testo));
                avviso(context, 'Copiato: incollalo in un messaggio a TecnikGeek');
              },
              child: const Text('Copia'),
            ),
            FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Continua')),
          ],
        ),
      );

  static int _ordine(CategoriaCliente c) => switch (c) {
        CategoriaCliente.daSaldare => 0,
        CategoriaCliente.inCorso => 1,
        CategoriaCliente.concluso => 2,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final clienti = archivio.clienti;
          final totale = clienti.fold<double>(0, (s, c) => s + c.totale);
          final incassato = clienti.fold<double>(0, (s, c) => s + c.incassato);
          final nDaSaldare = clienti.where((c) => c.categoria == CategoriaCliente.daSaldare).length;
          final filtrati = clienti
              .where((c) => _cerca.isEmpty || c.cliente.nome.toLowerCase().contains(_cerca.toLowerCase()))
              .where((c) => switch (_filtro) {
                    _Filtro.tutti => true,
                    _Filtro.inCorso => c.categoria == CategoriaCliente.inCorso,
                    _Filtro.daSaldare => c.categoria == CategoriaCliente.daSaldare,
                    _Filtro.conclusi => c.categoria == CategoriaCliente.concluso,
                  })
              .toList()
            ..sort((a, b) {
              final o = _ordine(a.categoria).compareTo(_ordine(b.categoria));
              return o != 0 ? o : b.ultimoAcconto.compareTo(a.ultimoAcconto);
            });

          return Scaffold(
            floatingActionButton: pulsanteNuovo('Nuovo cliente', () => vai(context, const SchermataModificaCliente())),
            body: Column(children: [
              Testata(
                sottotitolo: 'Acconti, clienti e segnalatori',
                azioni: [
                  AzioneTk(_cercando ? Icons.close_rounded : Icons.search_rounded, 'Cerca cliente', () {
                    setState(() {
                      _cercando = !_cercando;
                      if (!_cercando) _cerca = '';
                    });
                  }),
                  AzioneTk(Icons.settings_rounded, 'Impostazioni', () => vai(context, const SchermataImpostazioni())),
                  AzioneTk(Icons.info, 'Informazioni',
                      () => apriInformazioni(context, righe: () async => datiInformazioni(), notaDati: notaDati)),
                ],
                sotto: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_cercando) ...[
                    TextField(
                      autofocus: true,
                      onChanged: (t) => setState(() => _cerca = t.trim()),
                      decoration: const InputDecoration(
                          hintText: 'Cerca cliente…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('DA INCASSARE',
                      style: TextStyle(color: grigio300, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(euro((totale - incassato).clamp(0, double.infinity)),
                        style: const TextStyle(color: bianco, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 14, child: _Kpi(euro(incassato), 'Incassato')),
                    const SizedBox(width: 8),
                    Expanded(flex: 10, child: _Kpi('${clienti.length}', 'Clienti')),
                    const SizedBox(width: 8),
                    Expanded(flex: 10, child: _Kpi('$nDaSaldare', 'Da saldare')),
                  ]),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: accento,
                  onRefresh: () async {
                    if (!sincronizzazione.configurata) {
                      avviso(context, 'Per allineare col sito imposta indirizzo e password in Impostazioni');
                      return;
                    }
                    final esito = await sincronizzazione.sincronizza();
                    if (context.mounted) avviso(context, esito);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, 100 + MediaQuery.of(context).padding.bottom),
                    children: [
                      _cardSegnalatori(),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('Clienti', style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              for (final f in _Filtro.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _Chip(f.etichetta, f == _filtro, () => setState(() => _filtro = f)),
                                ),
                            ]),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      if (filtrati.isEmpty)
                        clienti.isEmpty
                            ? const StatoVuoto(Icons.waving_hand_rounded, 'Nessun cliente', 'Tocca «Nuovo cliente» per aggiungere il primo')
                            : const StatoVuoto(Icons.search_off_rounded, 'Nessun risultato', 'Prova un altro filtro o un altro nome')
                      else
                        for (final c in filtrati)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: _RigaCliente(c)),
                    ],
                  ),
                ),
              ),
            ]),
          );
        },
      );

  Widget _cardSegnalatori() {
    final seg = archivio.segnalatori;
    final daPagare = seg.fold<double>(0, (s, x) => s + x.daPagare);
    final pronti = seg.where((x) => x.pronto > 0).length;
    return CardTk(
      padding: const EdgeInsets.all(14),
      onTap: () => vai(context, const SchermataSegnalatori()),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: accentoChiaro, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.handshake_rounded, color: accentoScuro),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Segnalatori', style: TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(
              seg.isEmpty
                  ? 'Chi ti presenta i clienti'
                  : daPagare > 0
                      ? '${seg.length} · provvigioni da pagare ${euro(daPagare)}'
                      : '${seg.length} · provvigioni tutte pagate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        if (pronti > 0) ...[const SizedBox(width: 8), Badge2('$pronti da pagare', bluChiaro, blu)],
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: grigio300),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.valore, this.etichetta);

  final String valore, etichetta;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valore,
                maxLines: 1, style: const TextStyle(color: bianco, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Text(etichetta, style: const TextStyle(color: grigio300, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.testo, this.attivo, this.onTap);

  final String testo;
  final bool attivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: attivo ? navy : bianco,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), border: Border.all(color: attivo ? navy : grigio200)),
            child: Text(testo,
                style: TextStyle(color: attivo ? bianco : grigio500, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _RigaCliente extends StatelessWidget {
  const _RigaCliente(this.cc);

  final ClienteCompleto cc;

  @override
  Widget build(BuildContext context) {
    final c = cc.cliente;
    final perc = cc.totale > 0 ? (cc.incassato / cc.totale * 100).truncate().clamp(0, 100) : 0;
    final n = cc.progetti.length;
    final descrizione = n == 0
        ? 'Nessun progetto'
        : n == 1
            ? cc.progetti.first.progetto.nome
            : '${cc.progetti.first.progetto.nome} · $n progetti';
    return CardTk(
      padding: const EdgeInsets.all(14),
      onTap: () => vai(context, SchermataCliente(c.id)),
      child: Row(children: [
        Avatar(c.nome),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(c.nome.trim().isEmpty ? '(senza nome)' : c.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: navy, fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              badgeCategoria(cc.categoria),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(descrizione,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('${euro(cc.incassato)} su ${euro(cc.totale)}',
                  style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            BarraAvanzamento(perc,
                colore: coloreAvanzamento(perc, daSaldare: cc.categoria == CategoriaCliente.daSaldare)),
          ]),
        ),
      ]),
    );
  }
}

/// Riga in più del benvenuto: cosa va in rete con la sincronizzazione (solo verso il sito scelto dall'utente).
const righeBenvenuto = 'La **sincronizzazione** è facoltativa: se la attivi nelle Impostazioni, clienti, progetti '
    'e acconti vanno solo al **tuo sito** (pagina Acconti), con la password che scegli tu.';

/// Nota sotto «I tuoi dati» in Informazioni.
const notaDati = 'Restano su questo telefono; con la sincronizzazione anche sul tuo sito.';

/// Schede dati di Informazioni: quanti clienti, progetti, acconti e segnalatori, quanto c'è da incassare,
/// a che sito si sincronizza.
List<(String, String)> datiInformazioni() {
  final clienti = archivio.clienti;
  final progetti = clienti.fold<int>(0, (s, c) => s + c.progetti.length);
  final acconti = clienti.fold<int>(0, (s, c) => s + c.progetti.fold<int>(0, (t, p) => t + p.acconti.length));
  final totale = clienti.fold<double>(0, (s, c) => s + c.totale);
  final incassato = clienti.fold<double>(0, (s, c) => s + c.incassato);
  final sito = impostazioni.sito.replaceFirst(RegExp(r'^https?://'), '');
  return [
    ('Clienti', '${clienti.length}'),
    ('Progetti', '$progetti'),
    ('Acconti', '$acconti'),
    ('Segnalatori', '${archivio.segnalatori.length}'),
    ('Da incassare', euro((totale - incassato).clamp(0, double.infinity))),
    ('Sincronizzazione', sito.isEmpty ? 'spenta' : sito),
  ];
}
