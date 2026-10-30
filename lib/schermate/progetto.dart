// Scheda del progetto (anello, date, segnalatore riservato, acconti, riepilogo WhatsApp) e modulo progetto.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../dati/formati.dart';
import '../dati/modelli.dart';
import '../dati/whatsapp.dart';
import '../tema.dart';
import 'cliente.dart';
import 'home.dart';
import 'segnalatori.dart';

class SchermataProgetto extends StatelessWidget {
  const SchermataProgetto(this.id, {super.key});

  final int id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final pc = archivio.progetto(id);
          if (pc == null) {
            return Scaffold(body: Column(children: [TestataSemplice(titolo: 'Progetto', indietro: () => Navigator.pop(context))]));
          }
          final p = pc.progetto;
          final cliente = archivio.cliente(p.clienteId)?.cliente;
          final colore = coloreAvanzamento(pc.percentuale);
          final acconti = [...pc.acconti]..sort((a, b) => b.data.compareTo(a.data));
          return Scaffold(
            floatingActionButton: pulsanteNuovo('Acconto', () => dialogoAcconto(context, p.id, null)),
            body: Column(children: [
              Testata(
                titolo: p.nome,
                sottotitolo: cliente?.nome,
                logo: false,
                indietro: () => Navigator.pop(context),
                azioni: [
                  AzioneTk(Icons.edit_rounded, 'Modifica progetto',
                      () => vai(context, SchermataModificaProgetto(clienteId: p.clienteId, progetto: p))),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 100 + MediaQuery.of(context).padding.bottom),
                  children: [
                    CardTk(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        Anello(pc.percentuale, colore: colore),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Cifra(euro(p.totale), 'Totale', grande: true),
                            const SizedBox(height: 9),
                            Cifra(euro(pc.totalePagato), 'Incassato', grande: true),
                            const SizedBox(height: 9),
                            Cifra(euro(pc.residuo.clamp(0, double.infinity)), 'Residuo',
                                grande: true, colore: pc.residuo > 0 ? accentoTesto : verde),
                          ]),
                        ),
                      ]),
                    ),
                    if (p.dataInizio > 0 || p.dataFine > 0 || p.url.trim().isNotEmpty || p.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CardTk(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (p.dataInizio > 0 || p.dataFine > 0)
                            Row(children: [
                              Expanded(child: Voce('Inizio', dataBreve(p.dataInizio))),
                              Expanded(child: Voce('Consegna', dataBreve(p.dataFine))),
                            ]),
                          if (p.url.trim().isNotEmpty) ...[const SizedBox(height: 10), Voce('Sito', p.url, colore: blu)],
                          if (p.note.trim().isNotEmpty) ...[const SizedBox(height: 10), Voce('Note', p.note)],
                        ]),
                      ),
                    ],
                    if (p.segnalatoreId > 0) ...[
                      const SizedBox(height: 10),
                      _CardSegnalatore(
                        nome: p.presentatore,
                        stato: pc.statoProvvigione,
                        onApri: () => vai(context, SchermataSegnalatore(p.segnalatoreId)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Sezione('Acconti',
                        destra: acconti.isEmpty ? 'nessuno' : '${acconti.length} · ultimo ${dataBreve(acconti.first.data)}'),
                    const SizedBox(height: 6),
                    if (acconti.isEmpty)
                      const StatoVuoto(Icons.payments_rounded, 'Nessun acconto', 'Tocca «Acconto» per registrare il primo pagamento')
                    else ...[
                      for (var i = 0; i < acconti.length; i++)
                        _RigaTempo(acconti[i], primo: i == 0, ultimo: i == acconti.length - 1, colore: colore),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(6, 4, 6, 0),
                        child: Text('Scorri un acconto verso sinistra per eliminarlo, toccalo per modificarlo',
                            style: TextStyle(color: grigio400, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Material(
                      color: whatsapp,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final ok = await apriWhatsApp(cliente?.telefono ?? '', riepilogoCliente(cliente, pc));
                          if (!ok && context.mounted) avviso(context, 'Nessuna app di messaggistica disponibile su questo telefono');
                        },
                        child: const SizedBox(
                          height: 50,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.chat_rounded, color: bianco, size: 20),
                            SizedBox(width: 8),
                            Text('Invia riepilogo al cliente in chat',
                                style: TextStyle(color: bianco, fontWeight: FontWeight.w800)),
                          ]),
                        ),
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

/// «Segnalato da» riservato: chiusa mostra un lucchetto, al tocco si gira e rivela chi e lo stato.
class _CardSegnalatore extends StatefulWidget {
  const _CardSegnalatore({required this.nome, required this.stato, required this.onApri});

  final String nome;
  final StatoProvvigione stato;
  final VoidCallback onApri;

  @override
  State<_CardSegnalatore> createState() => _CardSegnalatoreState();
}

class _CardSegnalatoreState extends State<_CardSegnalatore> with SingleTickerProviderStateMixin {
  late final _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _giro.status == AnimationStatus.forward || _giro.status == AnimationStatus.completed
            ? _giro.reverse()
            : _giro.forward(),
        child: AnimatedBuilder(
          animation: _giro,
          builder: (_, _) {
            final angolo = Curves.easeInOut.transform(_giro.value) * math.pi;
            final retro = angolo > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY(angolo),
              child: Container(
                decoration: BoxDecoration(
                  color: bianco,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: retro ? accento : grigio200),
                ),
                child: retro
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Avatar(widget.nome, lato: 38, raggio: 12),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Segnalato da',
                                    style: TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text(widget.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                badgeProvvigione(widget.stato),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: navy,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: widget.onApri,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  child: Text('Apri scheda',
                                      style: TextStyle(color: bianco, fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      )
                    : const SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: Icon(Icons.lock_rounded, color: grigio300, size: 18),
                      ),
              ),
            );
          },
        ),
      );
}

/// Riga della linea del tempo degli acconti: pallino e filo a sinistra, scorri per eliminare, tocca per modificare.
class _RigaTempo extends StatelessWidget {
  const _RigaTempo(this.a, {required this.primo, required this.ultimo, required this.colore});

  final Acconto a;
  final bool primo, ultimo;
  final Color colore;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 24,
            child: Column(children: [
              Container(width: 2, height: 12, color: primo ? Colors.transparent : grigio200),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: bianco, shape: BoxShape.circle, border: Border.all(color: colore, width: 2)),
                child: Icon(Icons.check_rounded, color: colore, size: 12),
              ),
              Expanded(child: Container(width: 2, color: ultimo ? Colors.transparent : grigio200)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('a${a.id}'),
                direction: DismissDirection.endToStart,
                background: sfondoElimina(14),
                confirmDismiss: (_) async {
                  final si = await conferma(context, "Eliminare l'acconto?",
                      "Verrà eliminato l'acconto da ${euro(a.importo)} del ${dataBreve(a.data)}.");
                  if (si) await archivio.eliminaAcconto(a);
                  return false;
                },
                child: Material(
                  color: bianco,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => dialogoAcconto(context, a.progettoId, a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(euro(a.importo),
                                style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
                            Text('${dataBreve(a.data)}${a.note.trim().isNotEmpty ? ' · ${a.note}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: grigio500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: grigio300),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

/// Nuovo acconto o modifica di uno esistente.
Future<void> dialogoAcconto(BuildContext context, int progettoId, Acconto? acconto) async {
  final importo = TextEditingController(text: acconto != null && acconto.importo > 0 ? perCampo(acconto.importo) : '');
  final note = TextEditingController(text: acconto?.note ?? '');
  var data = (acconto != null && acconto.data > 0) ? acconto.data : oggi();
  String? errore;
  await showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, aggiorna) => AlertDialog(
        title: Text(acconto == null ? 'Nuovo acconto' : 'Modifica acconto'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: importo,
              autofocus: acconto == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => aggiorna(() => errore = null),
              decoration: InputDecoration(labelText: 'Importo (€) *', errorText: errore, prefixIcon: const Icon(Icons.euro_rounded)),
            ),
            const SizedBox(height: 12),
            CampoData('Data', data, (v) => aggiorna(() => data = v)),
            const SizedBox(height: 12),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (facoltative)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annulla')),
          FilledButton(
            onPressed: () async {
              final v = leggiImporto(importo.text);
              if (v <= 0) {
                aggiorna(() => errore = "Scrivi l'importo");
                return;
              }
              await archivio.salvaAcconto(
                  (acconto ?? Acconto()).copia(progettoId: progettoId, importo: v, data: data, note: note.text.trim()));
              if (d.mounted) Navigator.pop(d);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}

/// Campo data che apre il calendario (vuoto = nessuna data).
class CampoData extends StatelessWidget {
  const CampoData(this.etichetta, this.valore, this.onCambia, {super.key, this.cancellabile = false});

  final String etichetta;
  final int valore;
  final ValueChanged<int> onCambia;
  final bool cancellabile;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final iniziale = valore > 0 ? DateTime.fromMillisecondsSinceEpoch(valore) : DateTime.now();
          final scelta = await showDatePicker(
            context: context,
            initialDate: iniziale,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (scelta != null) onCambia(DateTime(scelta.year, scelta.month, scelta.day).millisecondsSinceEpoch);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etichetta,
            // icona del calendario finché è vuota, crocetta per toglierla quando c'è
            suffixIcon: cancellabile && valore > 0
                ? IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Togli la data', onPressed: () => onCambia(0))
                : const Icon(Icons.event_rounded),
          ),
          child: Text(valore > 0 ? dataBreve(valore) : '', maxLines: 1, style: const TextStyle(color: navy, fontSize: 15)),
        ),
      );
}

// ───────────────────────── modulo progetto ─────────────────────────

class SchermataModificaProgetto extends StatefulWidget {
  const SchermataModificaProgetto({super.key, required this.clienteId, this.progetto});

  final int clienteId;
  final Progetto? progetto;

  @override
  State<SchermataModificaProgetto> createState() => _SchermataModificaProgettoState();
}

class _SchermataModificaProgettoState extends State<SchermataModificaProgetto> {
  final _nome = TextEditingController();
  final _url = TextEditingController();
  final _totale = TextEditingController();
  final _note = TextEditingController();
  final _provvigione = TextEditingController();
  late int _inizio, _fine;
  int _segnalatoreId = 0;
  bool _pagata = false, _finito = false;
  String? _erroreNome, _erroreTotale;

  @override
  void initState() {
    super.initState();
    final p = widget.progetto;
    _inizio = p?.dataInizio ?? oggi();
    _fine = p?.dataFine ?? 0;
    if (p != null) {
      _nome.text = p.nome;
      _url.text = p.url;
      _totale.text = p.totale > 0 ? perCampo(p.totale) : '';
      _note.text = p.note;
      _segnalatoreId = p.segnalatoreId;
      _provvigione.text = p.provvigione > 0 ? perCampo(p.provvigione) : '';
      _pagata = p.provvigionePagata;
      _finito = p.lavoroFinito;
    }
  }

  Future<void> _salva() async {
    final tot = leggiImporto(_totale.text);
    setState(() {
      _erroreNome = _nome.text.trim().isEmpty ? 'Scrivi il nome del progetto' : null;
      _erroreTotale = tot <= 0 ? 'Scrivi il totale concordato' : null;
    });
    if (_erroreNome != null || _erroreTotale != null) return;
    final vecchio = widget.progetto;
    final conSegn = _segnalatoreId > 0;
    final p = (vecchio ?? Progetto()).copia(
      clienteId: widget.clienteId,
      nome: _nome.text.trim(),
      url: _url.text.trim(),
      totale: tot,
      dataInizio: _inizio,
      dataFine: _fine,
      note: _note.text.trim(),
      segnalatoreId: _segnalatoreId,
      provvigione: conSegn ? leggiImporto(_provvigione.text) : 0,
      provvigionePagata: conSegn && _pagata,
      lavoroFinito: conSegn && _finito,
      provvigionePagataIl: !conSegn || !_pagata
          ? 0
          : (vecchio?.provvigionePagata == true ? vecchio!.provvigionePagataIl : adesso()),
    );
    final id = await archivio.salvaProgetto(p);
    if (!mounted) return;
    if (vecchio == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SchermataProgetto(id)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final scelto = archivio.segnalatore(_segnalatoreId)?.segnalatore;
          return Scaffold(
            body: Column(children: [
              TestataSemplice(
                titolo: widget.progetto == null ? 'Nuovo progetto' : 'Modifica progetto',
                indietro: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + MediaQuery.of(context).padding.bottom),
                  children: [
                    CardTk(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const TitoloSezione('Progetto'),
                        const SizedBox(height: 10),
                        campo('Nome progetto *', _nome,
                            errore: _erroreNome, onChanged: (_) => setState(() => _erroreNome = null)),
                        campo('Sito / indirizzo', _url, tastiera: TextInputType.url),
                        campo('Totale concordato (€) *', _totale,
                            errore: _erroreTotale,
                            tastiera: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _erroreTotale = null)),
                        Row(children: [
                          Expanded(child: CampoData('Inizio', _inizio, (v) => setState(() => _inizio = v), cancellabile: true)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: CampoData('Consegna prevista', _fine, (v) => setState(() => _fine = v), cancellabile: true)),
                        ]),
                        const SizedBox(height: 12),
                        campo('Note', _note, righe: 3),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    CardTk(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Expanded(child: TitoloSezione('Segnalato da')),
                          Icon(Icons.lock_rounded, color: grigio300, size: 18),
                        ]),
                        const SizedBox(height: 6),
                        const Text('Riservato: compare solo nella scheda progetto, mai nel riepilogo al cliente.',
                            style: TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final id = await sceltaSegnalatore(context, _segnalatoreId);
                            if (id != null) setState(() => _segnalatoreId = id);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Segnalatore',
                                prefixIcon: Icon(Icons.handshake_rounded),
                                suffixIcon: Icon(Icons.arrow_drop_down_rounded)),
                            child: Text(scelto?.nome ?? 'Nessuno', style: const TextStyle(color: navy, fontSize: 15)),
                          ),
                        ),
                        if (_segnalatoreId > 0) ...[
                          const SizedBox(height: 12),
                          campo('Provvigione (€)', _provvigione, tastiera: const TextInputType.numberWithOptions(decimal: true)),
                          _spunta('Lavoro finito (anche se il cliente non ha saldato)', _finito, (v) => setState(() => _finito = v)),
                          _spunta('Provvigione già pagata', _pagata, (v) => setState(() => _pagata = v)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    BottoneTk(testo: 'Salva progetto', icona: Icons.check_rounded, onTap: _salva),
                  ],
                ),
              ),
            ]),
          );
        },
      );

  Widget _spunta(String testo, bool v, ValueChanged<bool> cambia) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => cambia(!v),
        child: Row(children: [
          Checkbox(value: v, activeColor: verde, onChanged: (x) => cambia(x ?? false)),
          Expanded(child: Text(testo, style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Elenco per scegliere il segnalatore: «Nessuno», quelli esistenti, oppure uno nuovo al volo.
/// Restituisce l'id scelto (0 = nessuno) o null se si chiude.
Future<int?> sceltaSegnalatore(BuildContext context, int attuale) => showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (f) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(f).size.height * .7),
          child: ListView(shrinkWrap: true, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Segnalato da', style: TextStyle(color: navy, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            _voce('Nessuno', '', attuale == 0, () => Navigator.pop(f, 0)),
            for (final s in archivio.segnalatori)
              _voce(s.segnalatore.nome, s.segnalatore.telefono, s.segnalatore.id == attuale,
                  () => Navigator.pop(f, s.segnalatore.id)),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded, color: accentoScuro),
              title: const Text('Nuovo segnalatore', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final id = await vai<int>(f, const SchermataModificaSegnalatore(restituisciId: true));
                if (id != null && f.mounted) Navigator.pop(f, id);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

Widget _voce(String nome, String telefono, bool scelto, VoidCallback onTap) => ListTile(
      leading: nome == 'Nessuno'
          ? const CircleAvatar(backgroundColor: grigio100, child: Icon(Icons.block_rounded, color: grigio500))
          : Avatar(nome, lato: 38, raggio: 12),
      title: Text(nome, style: const TextStyle(color: navy, fontWeight: FontWeight.w700)),
      subtitle: telefono.trim().isEmpty ? null : Text(telefono),
      trailing: scelto ? const Icon(Icons.check_circle_rounded, color: accentoScuro) : null,
      selected: scelto,
      selectedTileColor: accentoChiaro,
      onTap: onTap,
    );
