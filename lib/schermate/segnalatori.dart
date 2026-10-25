// Segnalatori: elenco, scheda con i lavori portati e le provvigioni, modulo.
import 'package:flutter/material.dart';

import '../app.dart';
import '../dati/formati.dart';
import '../dati/modelli.dart';
import '../dati/whatsapp.dart';
import '../tema.dart';
import 'cliente.dart';
import 'home.dart';
import 'progetto.dart';

class SchermataSegnalatori extends StatelessWidget {
  const SchermataSegnalatori({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final seg = archivio.segnalatori;
          // prima chi ha compensi pronti, poi chi ha ancora qualcosa in sospeso
          final ordinati = [...seg]..sort((a, b) {
              final x = (b.pronto > 0 ? 1 : 0).compareTo(a.pronto > 0 ? 1 : 0);
              if (x != 0) return x;
              final y = (b.daPagare > 0 ? 1 : 0).compareTo(a.daPagare > 0 ? 1 : 0);
              if (y != 0) return y;
              return a.segnalatore.nome.toLowerCase().compareTo(b.segnalatore.nome.toLowerCase());
            });
          return Scaffold(
            floatingActionButton: pulsanteNuovo('Segnalatore', () => vai(context, const SchermataModificaSegnalatore())),
            body: Column(children: [
              Testata(
                titolo: 'Segnalatori',
                sottotitolo: 'Chi ti presenta i clienti',
                logo: false,
                indietro: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 100 + MediaQuery.of(context).padding.bottom),
                  children: [
                    if (seg.isNotEmpty) ...[
                      CardTk(
                        child: Row(children: [
                          Expanded(child: Cifra(euro(seg.fold(0.0, (s, x) => s + x.totaleProvvigioni)), 'Provvigioni')),
                          Expanded(child: Cifra(euro(seg.fold(0.0, (s, x) => s + x.pagato)), 'Pagate', colore: verde)),
                          Expanded(
                              child: Cifra(euro(seg.fold(0.0, (s, x) => s + x.daPagare)), 'Da pagare', colore: accentoTesto)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (ordinati.isEmpty)
                      const StatoVuoto(Icons.handshake_rounded, 'Nessun segnalatore',
                          'Tocca «Segnalatore» oppure scegli «Segnalato da» in un progetto')
                    else
                      for (final s in ordinati) Padding(padding: const EdgeInsets.only(bottom: 10), child: _Riga(s)),
                  ],
                ),
              ),
            ]),
          );
        },
      );
}

class _Riga extends StatelessWidget {
  const _Riga(this.sp);

  final SegnalatoreConProgetti sp;

  @override
  Widget build(BuildContext context) {
    final s = sp.segnalatore;
    final n = sp.progetti.length;
    return CardTk(
      padding: const EdgeInsets.all(14),
      onTap: () => vai(context, SchermataSegnalatore(s.id)),
      child: Row(children: [
        Avatar(s.nome),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(s.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: navy, fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              if (sp.pronto > 0)
                const Badge2('Da pagare', bluChiaro, blu)
              else if (sp.daPagare > 0)
                const Badge2('In attesa', accentoChiaro, accentoTesto)
              else if (n > 0)
                const Badge2('Saldato', verdeChiaro, verde),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(n == 1 ? '1 lavoro portato' : '$n lavori portati',
                    style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text(sp.daPagare > 0 ? 'da pagare ${euro(sp.daPagare)}' : euro(sp.totaleProvvigioni),
                  style: TextStyle(
                      color: sp.daPagare > 0 ? accentoTesto : grigio500, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class SchermataSegnalatore extends StatelessWidget {
  const SchermataSegnalatore(this.id, {super.key});

  final int id;

  static int _ordine(StatoProvvigione s) => switch (s) {
        StatoProvvigione.lavoroFinito => 0,
        StatoProvvigione.daMaturare => 1,
        StatoProvvigione.pagata => 2,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final sp = archivio.segnalatore(id);
          if (sp == null) {
            return Scaffold(
                body: Column(children: [TestataSemplice(titolo: 'Segnalatore', indietro: () => Navigator.pop(context))]));
          }
          final s = sp.segnalatore;
          final lavori = [...sp.progetti]..sort((a, b) {
              final o = _ordine(a.statoProvvigione).compareTo(_ordine(b.statoProvvigione));
              return o != 0 ? o : b.progetto.createdAt.compareTo(a.progetto.createdAt);
            });
          String? nomeCliente(ProgettoConAcconti pc) => archivio.cliente(pc.progetto.clienteId)?.cliente.nome;

          Future<void> whatsApp(ProgettoConAcconti pc, StatoProvvigione stato) async {
            final ok = await apriWhatsApp(
                s.telefono, messaggioSegnalatore(stato, s.nome, pc.progetto.nome, nomeCliente(pc), pc.progetto.provvigione));
            if (!ok && context.mounted) avviso(context, 'WhatsApp non disponibile su questo telefono');
          }

          Future<void> avanza(ProgettoConAcconti pc) async {
            final stato = pc.statoProvvigione;
            StatoProvvigione? nuovo;
            if (stato == StatoProvvigione.daMaturare) {
              await archivio.cambiaLavoroFinito(pc.progetto);
              nuovo = StatoProvvigione.lavoroFinito;
            } else {
              await archivio.cambiaProvvigionePagata(pc.progetto);
              if (stato == StatoProvvigione.lavoroFinito) nuovo = StatoProvvigione.pagata;
            }
            if (nuovo == null || s.telefono.trim().isEmpty || !context.mounted) return;
            final si = await conferma(
              context,
              nuovo == StatoProvvigione.pagata ? 'Provvigione pagata' : 'Lavoro finito',
              'Vuoi avvisare ${s.nome.trim().split(' ').first} su WhatsApp?',
              si: 'Invia messaggio',
              pericolo: false,
            );
            if (si) await whatsApp(pc, nuovo);
          }

          return Scaffold(
            body: Column(children: [
              Testata(
                titolo: s.nome,
                sottotitolo: s.telefono.trim().isEmpty ? null : s.telefono,
                logo: false,
                indietro: () => Navigator.pop(context),
                azioni: [
                  AzioneTk(Icons.edit_rounded, 'Modifica segnalatore',
                      () => vai(context, SchermataModificaSegnalatore(segnalatore: s))),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + MediaQuery.of(context).padding.bottom),
                  children: [
                    CardTk(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Avatar(s.nome, lato: 52, raggio: 16),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
                              Text(sp.progetti.length == 1 ? '1 lavoro portato' : '${sp.progetti.length} lavori portati',
                                  style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Cifra(euro(sp.totaleProvvigioni), 'Totale')),
                          Expanded(child: Cifra(euro(sp.pagato), 'Pagato', colore: verde)),
                          Expanded(
                              child: Cifra(euro(sp.daPagare), 'Da pagare', colore: sp.daPagare > 0 ? accentoTesto : verde)),
                        ]),
                        if (sp.pronto > 0) ...[
                          const SizedBox(height: 10),
                          Text('${euro(sp.pronto)} pronti da pagare (lavori finiti)',
                              style: const TextStyle(color: blu, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ]),
                    ),
                    if (s.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CardTk(padding: const EdgeInsets.all(14), child: Voce('Note', s.note)),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      if (s.telefono.trim().isNotEmpty) ...[
                        Expanded(
                          child: Tasto('Scrivi su WhatsApp',
                              icona: Icons.chat_rounded,
                              colore: bianco,
                              fondo: whatsapp,
                              onTap: () => apriWhatsApp(s.telefono, 'Ciao ${s.nome.trim().split(' ').first}! ')),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Tasto('Elimina segnalatore', colore: grigio500, fondo: bianco, onTap: () async {
                          final si = await conferma(context, 'Eliminare il segnalatore?',
                              '«${s.nome}» verrà eliminato. I progetti restano, senza segnalatore e senza provvigione collegata.');
                          if (!si) return;
                          await archivio.eliminaSegnalatore(s);
                          if (context.mounted) Navigator.pop(context);
                        }),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Sezione('Lavori portati', destra: '${lavori.length}'),
                    const SizedBox(height: 6),
                    if (lavori.isEmpty)
                      const StatoVuoto(Icons.folder_open_rounded, 'Nessun lavoro',
                          'Scegli questo segnalatore in «Segnalato da» di un progetto')
                    else
                      for (final pc in lavori)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _Lavoro(
                            pc: pc,
                            nomeCliente: nomeCliente(pc),
                            haTelefono: s.telefono.trim().isNotEmpty,
                            onWhatsApp: () => whatsApp(pc, pc.statoProvvigione),
                            onAvanza: () => avanza(pc),
                          ),
                        ),
                  ],
                ),
              ),
            ]),
          );
        },
      );
}

class _Lavoro extends StatelessWidget {
  const _Lavoro(
      {required this.pc, required this.nomeCliente, required this.haTelefono, required this.onWhatsApp, required this.onAvanza});

  final ProgettoConAcconti pc;
  final String? nomeCliente;
  final bool haTelefono;
  final VoidCallback onWhatsApp, onAvanza;

  @override
  Widget build(BuildContext context) {
    final p = pc.progetto;
    final stato = pc.statoProvvigione;
    return CardTk(
      padding: const EdgeInsets.all(14),
      onTap: () => vai(context, SchermataProgetto(p.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: navy, fontSize: 14.5, fontWeight: FontWeight.w800)),
              Text(
                  [if (nomeCliente != null && nomeCliente!.trim().isNotEmpty) nomeCliente!, 'lavoro al ${pc.percentuale}% incassato']
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(euro(p.provvigione), style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            badgeProvvigione(stato),
          ]),
        ]),
        if (stato == StatoProvvigione.pagata && p.provvigionePagataIl > 0) ...[
          const SizedBox(height: 4),
          Text('pagata il ${dataBreve(p.provvigionePagataIl)}',
              style: const TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (haTelefono) ...[
            Expanded(
              child: Tasto(etichettaWhatsAppSegnalatore(stato),
                  icona: Icons.chat_rounded, colore: bianco, fondo: whatsapp, onTap: onWhatsApp),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: switch (stato) {
              StatoProvvigione.daMaturare => Tasto('Segna lavoro finito', colore: blu, fondo: bluChiaro, onTap: onAvanza),
              StatoProvvigione.lavoroFinito => Tasto('Segna pagata', colore: verde, fondo: verdeChiaro, onTap: onAvanza),
              StatoProvvigione.pagata => Tasto('Annulla pagamento', colore: grigio500, fondo: bianco, onTap: onAvanza),
            },
          ),
        ]),
      ]),
    );
  }
}

class SchermataModificaSegnalatore extends StatefulWidget {
  const SchermataModificaSegnalatore({super.key, this.segnalatore, this.restituisciId = false});

  final Segnalatore? segnalatore;

  /// Aperta dalla scelta «Segnalato da»: torna indietro con l'id del nuovo segnalatore.
  final bool restituisciId;

  @override
  State<SchermataModificaSegnalatore> createState() => _SchermataModificaSegnalatoreState();
}

class _SchermataModificaSegnalatoreState extends State<SchermataModificaSegnalatore> {
  late final _nome = TextEditingController(text: widget.segnalatore?.nome ?? '');
  late final _telefono = TextEditingController(text: widget.segnalatore?.telefono ?? '');
  late final _note = TextEditingController(text: widget.segnalatore?.note ?? '');
  String? _errore;

  Future<void> _salva() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _errore = 'Scrivi nome e cognome');
      return;
    }
    final id = await archivio.salvaSegnalatore((widget.segnalatore ?? Segnalatore())
        .copia(nome: _nome.text.trim(), telefono: _telefono.text.trim(), note: _note.text.trim()));
    if (!mounted) return;
    if (widget.restituisciId) {
      Navigator.pop(context, id);
    } else if (widget.segnalatore == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SchermataSegnalatore(id)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TestataSemplice(
            titolo: widget.segnalatore == null ? 'Nuovo segnalatore' : 'Modifica segnalatore',
            indietro: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                CardTk(
                  child: Column(children: [
                    campo('Nome e cognome *', _nome,
                        errore: _errore, maiuscole: true, onChanged: (_) => setState(() => _errore = null)),
                    campo('Telefono (WhatsApp)', _telefono, tastiera: TextInputType.phone),
                    campo('Note', _note, righe: 3),
                  ]),
                ),
                const SizedBox(height: 16),
                BottoneTk(testo: 'Salva segnalatore', icona: Icons.check_rounded, onTap: _salva),
              ],
            ),
          ),
        ]),
      );
}
