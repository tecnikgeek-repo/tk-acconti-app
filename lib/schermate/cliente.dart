// Scheda del cliente (riepilogo, contatti, progetti) e modulo nuovo/modifica cliente.
import 'package:flutter/material.dart';

import '../app.dart';
import '../dati/formati.dart';
import '../dati/modelli.dart';
import '../tema.dart';
import 'home.dart';
import 'progetto.dart';

class SchermataCliente extends StatelessWidget {
  const SchermataCliente(this.id, {super.key});

  final int id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: archivio,
        builder: (context, _) {
          final cc = archivio.cliente(id);
          if (cc == null) {
            return Scaffold(body: Column(children: [TestataSemplice(titolo: 'Cliente', indietro: () => Navigator.pop(context))]));
          }
          final c = cc.cliente;
          return Scaffold(
            floatingActionButton:
                pulsanteNuovo('Nuovo progetto', () => vai(context, SchermataModificaProgetto(clienteId: c.id))),
            body: Column(children: [
              Testata(
                titolo: c.nome.trim().isEmpty ? 'Cliente' : c.nome,
                sottotitolo: c.telefono.trim().isEmpty ? null : c.telefono,
                logo: false,
                indietro: () => Navigator.pop(context),
                azioni: [
                  AzioneTk(Icons.edit_rounded, 'Modifica cliente', () => vai(context, SchermataModificaCliente(cliente: c))),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 100 + MediaQuery.of(context).padding.bottom),
                  children: [
                    CardTk(
                      child: Column(children: [
                        Row(children: [
                          Avatar(c.nome, lato: 52, raggio: 16),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              badgeCategoria(cc.categoria),
                              const SizedBox(height: 4),
                              Text('${cc.progetti.length} ${cc.progetti.length == 1 ? 'progetto' : 'progetti'}',
                                  style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Cifra(euro(cc.totale), 'Totale lavori')),
                          Expanded(child: Cifra(euro(cc.incassato), 'Incassato', colore: verde)),
                          Expanded(
                            child: Cifra(euro(cc.residuo.clamp(0, double.infinity)), 'Da incassare',
                                colore: cc.residuo > 0 ? accentoTesto : verde),
                          ),
                        ]),
                      ]),
                    ),
                    if (c.email.trim().isNotEmpty || c.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CardTk(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (c.email.trim().isNotEmpty) Voce('Email', c.email),
                          if (c.email.trim().isNotEmpty && c.note.trim().isNotEmpty) const SizedBox(height: 8),
                          if (c.note.trim().isNotEmpty) Voce('Note', c.note),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: Tasto(c.daSaldare ? 'Togli «da saldare»' : 'Segna da saldare',
                            colore: rosso, fondo: rossoChiaro, onTap: () => archivio.cambiaDaSaldare(c)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tasto('Elimina cliente', colore: grigio500, fondo: bianco, onTap: () async {
                          final si = await conferma(context, 'Eliminare il cliente?',
                              '«${c.nome}» e tutti i suoi progetti e acconti verranno eliminati. Operazione non annullabile.');
                          if (!si) return;
                          await archivio.eliminaCliente(c);
                          if (context.mounted) Navigator.pop(context);
                        }),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Sezione('Progetti', destra: '${cc.progetti.length}'),
                    const SizedBox(height: 6),
                    if (cc.progetti.isEmpty)
                      const StatoVuoto(Icons.folder_open_rounded, 'Nessun progetto', 'Tocca «Nuovo progetto» per crearne uno')
                    else ...[
                      for (final pc in cc.progetti)
                        Padding(padding: const EdgeInsets.only(bottom: 10), child: _RigaProgetto(pc)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Scorri un progetto verso sinistra per eliminarlo',
                            style: TextStyle(color: grigio400, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          );
        },
      );
}

/// Sfondo rosso «Elimina» dietro una riga che si scorre verso sinistra.
Widget sfondoElimina(double raggio) => Container(
      decoration: BoxDecoration(color: rosso, borderRadius: BorderRadius.circular(raggio)),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_rounded, color: bianco, size: 18),
        SizedBox(width: 6),
        Text('Elimina', style: TextStyle(color: bianco, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );

class _RigaProgetto extends StatelessWidget {
  const _RigaProgetto(this.pc);

  final ProgettoConAcconti pc;

  @override
  Widget build(BuildContext context) {
    final p = pc.progetto;
    final colore = coloreAvanzamento(pc.percentuale);
    return Dismissible(
      key: ValueKey('p${p.id}'),
      direction: DismissDirection.endToStart,
      background: sfondoElimina(18),
      confirmDismiss: (_) async {
        final si = await conferma(context, 'Eliminare il progetto?', '«${p.nome}» e i suoi acconti verranno eliminati.');
        if (si) await archivio.eliminaProgetto(p);
        return false; // la riga sparisce da sola quando l'archivio si aggiorna
      },
      child: CardTk(
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
                if (p.url.trim().isNotEmpty)
                  Text(p.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 10),
            Text('${pc.percentuale}%', style: TextStyle(color: colore, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text('${euro(pc.totalePagato)} su ${euro(p.totale)}',
                  style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            if (p.dataFine > 0)
              Text('consegna ${dataBreve(p.dataFine)}',
                  style: const TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          BarraAvanzamento(pc.percentuale, colore: colore),
        ]),
      ),
    );
  }
}

// ───────────────────────── modulo cliente ─────────────────────────

class SchermataModificaCliente extends StatefulWidget {
  const SchermataModificaCliente({super.key, this.cliente});

  final Cliente? cliente;

  @override
  State<SchermataModificaCliente> createState() => _SchermataModificaClienteState();
}

class _SchermataModificaClienteState extends State<SchermataModificaCliente> {
  final _nomeWA = TextEditingController();
  final _cognome = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  bool _erroreNome = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    if (c != null) {
      // il nome completo è «nome per WhatsApp» + cognome, come nella versione precedente
      final nomeWA = c.nomeWA.trim().isNotEmpty ? c.nomeWA.trim() : c.nome.trim().split(' ').first;
      _nomeWA.text = nomeWA;
      _cognome.text = c.nomeWA.trim().isNotEmpty
          ? c.nome.replaceFirst(c.nomeWA, '').trim()
          : (c.nome.trim().contains(' ') ? c.nome.trim().substring(c.nome.trim().indexOf(' ') + 1) : '');
      _telefono.text = c.telefono;
      _email.text = c.email;
      _note.text = c.note;
    }
  }

  Future<void> _salva() async {
    if (_nomeWA.text.trim().isEmpty) {
      setState(() => _erroreNome = true);
      return;
    }
    final nome = _cognome.text.trim().isEmpty ? _nomeWA.text.trim() : '${_nomeWA.text.trim()} ${_cognome.text.trim()}';
    final c = (widget.cliente ?? Cliente()).copia(
      nome: nome,
      nomeWA: _nomeWA.text.trim(),
      telefono: _telefono.text.trim(),
      email: _email.text.trim(),
      note: _note.text.trim(),
    );
    final id = await archivio.salvaCliente(c);
    if (!mounted) return;
    if (widget.cliente == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SchermataCliente(id)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TestataSemplice(
            titolo: widget.cliente == null ? 'Nuovo cliente' : 'Modifica cliente',
            indietro: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                CardTk(
                  child: Column(children: [
                    campo('Nome (per WhatsApp) *', _nomeWA,
                        errore: _erroreNome ? 'Scrivi il nome' : null,
                        onChanged: (_) => setState(() => _erroreNome = false),
                        maiuscole: true),
                    campo('Cognome / Ragione sociale', _cognome, maiuscole: true),
                    campo('Telefono (WhatsApp)', _telefono, tastiera: TextInputType.phone),
                    campo('Email', _email, tastiera: TextInputType.emailAddress),
                    campo('Note', _note, righe: 3),
                  ]),
                ),
                const SizedBox(height: 16),
                BottoneTk(testo: 'Salva', icona: Icons.check_rounded, onTap: _salva),
              ],
            ),
          ),
        ]),
      );
}

/// Campo di testo dei moduli, con l'etichetta sopra.
Widget campo(String etichetta, TextEditingController c,
        {String? errore,
        ValueChanged<String>? onChanged,
        TextInputType? tastiera,
        int righe = 1,
        bool maiuscole = false,
        bool nascosto = false,
        Widget? suffisso}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        obscureText: nascosto,
        keyboardType: righe > 1 ? TextInputType.multiline : tastiera,
        minLines: righe > 1 ? 2 : 1,
        maxLines: righe > 1 ? righe + 3 : 1,
        textCapitalization: maiuscole
            ? TextCapitalization.words
            : (tastiera == null ? TextCapitalization.sentences : TextCapitalization.none),
        decoration: InputDecoration(labelText: etichetta, errorText: errore, suffixIcon: suffisso),
      ),
    );
