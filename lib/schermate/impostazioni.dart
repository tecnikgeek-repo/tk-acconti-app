// Impostazioni: blocco con PIN e impronta, sincronizzazione col sito, backup JSON.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../dati/formati.dart';
import '../dati/sincronizzazione.dart';
import '../tema.dart';
import 'blocco.dart';
import 'cliente.dart';

class SchermataImpostazioni extends StatefulWidget {
  const SchermataImpostazioni({super.key});

  @override
  State<SchermataImpostazioni> createState() => _SchermataImpostazioniState();
}

class _SchermataImpostazioniState extends State<SchermataImpostazioni> {
  late final _sito = TextEditingController(text: impostazioni.sito.isEmpty ? sitoPredefinito : impostazioni.sito);
  late final _password = TextEditingController(text: impostazioni.password);
  bool _vedi = false;
  bool _bioDisponibile = false;

  @override
  void initState() {
    super.initState();
    biometriaDisponibile().then((v) {
      if (mounted) setState(() => _bioDisponibile = v);
    });
  }

  Future<void> _impostaPin() async {
    final pin1 = TextEditingController(), pin2 = TextEditingController();
    String? errore;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, aggiorna) => AlertDialog(
          title: Text(impostazioni.haPin ? 'Cambia PIN' : 'Imposta PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Almeno 4 cifre.', style: TextStyle(color: grigio500, fontSize: 12.5))),
            const SizedBox(height: 10),
            for (final (c, et) in [(pin1, 'Nuovo PIN'), (pin2, 'Ripeti PIN')])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: c,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                  onChanged: (_) => aggiorna(() => errore = null),
                  decoration: InputDecoration(labelText: et),
                ),
              ),
            if (errore != null) Text(errore!, style: const TextStyle(color: rosso, fontSize: 12.5)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                if (pin1.text.length < 4) return aggiorna(() => errore = 'Il PIN deve avere almeno 4 cifre');
                if (pin1.text != pin2.text) return aggiorna(() => errore = 'I due PIN non coincidono');
                Navigator.pop(d, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await impostazioni.salvaPin(pin1.text);
    if (!mounted) return;
    setState(() {});
    avviso(context, 'PIN impostato: verrà chiesto alla prossima apertura');
  }

  Future<void> _sincronizza() async {
    if (_password.text.trim().isEmpty) return avviso(context, 'Scrivi la password di Acconti del sito');
    await impostazioni.salvaSync(_sito.text.trim().isEmpty ? sitoPredefinito : _sito.text, _password.text);
    _sito.text = impostazioni.sito;
    final esito = await sincronizzazione.sincronizza();
    if (mounted) avviso(context, esito);
  }

  Future<void> _esporta() async {
    final json = Uint8List.fromList(utf8.encode(archivio.esportaBackup()));
    const nome = 'tk-acconti-backup.json';
    try {
      if (Platform.isAndroid) {
        final p = await FilePicker.saveFile(fileName: nome, bytes: json, mimeType: 'application/json');
        if (p != null && mounted) avviso(context, 'Backup esportato');
      } else {
        final f = File('${(await getTemporaryDirectory()).path}/$nome');
        await f.writeAsBytes(json);
        await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'Backup di tk-acconti'));
      }
    } catch (e) {
      if (mounted) avviso(context, 'Esportazione non riuscita: $e');
    }
  }

  Future<void> _importa() async {
    final f = await FilePicker.pickFile();
    if (f == null || !mounted) return;
    final si = await conferma(context, 'Importare il backup?',
        'Tutti i dati di questo telefono verranno sostituiti con quelli del file «${f.name}».',
        si: 'Importa');
    if (!si) return;
    try {
      final n = await archivio.importaBackup(utf8.decode(await f.readAsBytes(), allowMalformed: true));
      if (mounted) avviso(context, 'Importati $n clienti');
    } catch (e) {
      if (mounted) avviso(context, 'Importazione non riuscita: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TestataSemplice(titolo: 'Impostazioni', indietro: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                _card(Icons.lock_rounded, 'Sicurezza', [
                  Text(impostazioni.haPin ? 'Blocco con PIN attivo.' : "Nessun blocco: l'app si apre liberamente.",
                      style: const TextStyle(color: grigio500, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: BottoneTk(
                            testo: impostazioni.haPin ? 'Cambia PIN' : 'Imposta PIN', icona: Icons.pin_rounded, onTap: _impostaPin)),
                    if (impostazioni.haPin) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: BottoneTk(
                          testo: 'Rimuovi',
                          chiaro: true,
                          onTap: () async {
                            await impostazioni.rimuoviPin();
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ],
                  ]),
                  if (impostazioni.haPin && _bioDisponibile) ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: accento,
                      title: const Text('Sblocco con impronta / volto',
                          style: TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Più veloce del PIN'),
                      value: impostazioni.biometria,
                      onChanged: (v) async {
                        await impostazioni.impostaBiometria(v);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: sincronizzazione,
                  builder: (context, _) => _card(Icons.sync_rounded, 'Sincronizzazione col sito', [
                    const Text(
                        'Tiene allineati telefono e pagina Acconti del sito: per ogni cliente, progetto o acconto '
                        'vince la modifica più recente. Serve il plugin tk-acconti 1.5.0 o successivo.',
                        style: TextStyle(color: grigio500, fontSize: 13)),
                    const SizedBox(height: 12),
                    campo('Indirizzo del sito', _sito, tastiera: TextInputType.url),
                    campo('Password di Acconti', _password,
                        tastiera: TextInputType.visiblePassword,
                        nascosto: !_vedi,
                        suffisso: IconButton(
                          tooltip: _vedi ? 'Nascondi' : 'Mostra',
                          icon: Icon(_vedi ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _vedi = !_vedi),
                        )),
                    BottoneTk(
                      testo: sincronizzazione.inCorso ? 'Sincronizzazione in corso…' : 'Salva e sincronizza ora',
                      icona: Icons.sync_rounded,
                      onTap: sincronizzazione.inCorso ? null : _sincronizza,
                    ),
                    if (sincronizzazione.ultima > 0) ...[
                      const SizedBox(height: 8),
                      Text('Ultima: ${dataOra(sincronizzazione.ultima)} · ${sincronizzazione.esito}',
                          style: TextStyle(color: sincronizzazione.ultimaOk ? grigio500 : rosso, fontSize: 12)),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                _card(Icons.save_rounded, 'Backup dei dati', [
                  const Text(
                      'Esporta un file JSON con tutti i dati (si apre anche con il plugin WordPress). '
                      "L'importazione sostituisce i dati di questo telefono.",
                      style: TextStyle(color: grigio500, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: BottoneTk(testo: 'Esporta', icona: Icons.upload_rounded, onTap: _esporta)),
                    const SizedBox(width: 10),
                    Expanded(child: BottoneTk(testo: 'Importa', icona: Icons.download_rounded, chiaro: true, onTap: _importa)),
                  ]),
                ]),
              ],
            ),
          ),
        ]),
      );

  Widget _card(IconData icona, String titolo, List<Widget> figli) => CardTk(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icona, color: accentoScuro, size: 20),
            const SizedBox(width: 8),
            Text(titolo, style: const TextStyle(color: navy, fontSize: 15.5, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ...figli,
        ]),
      );
}
