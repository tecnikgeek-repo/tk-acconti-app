// Messaggi WhatsApp: riepilogo al cliente (identico al plugin) e i 5 messaggi a caso per stato al segnalatore.
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import 'formati.dart';
import 'modelli.dart';

/// Apre WhatsApp verso il numero (prefisso 39 se manca) con il testo già scritto.
Future<bool> apriWhatsApp(String telefono, String testo) async {
  var tel = telefono.replaceAll(RegExp(r'\D'), '');
  if (tel.isNotEmpty && !tel.startsWith('39')) tel = '39$tel';
  final url = tel.isNotEmpty
      ? 'https://wa.me/$tel?text=${Uri.encodeComponent(testo)}'
      : 'https://wa.me/?text=${Uri.encodeComponent(testo)}';
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Riepilogo del progetto per il cliente: stesso testo della funzione inviaWA() del plugin.
/// Il segnalatore e la provvigione non compaiono mai qui.
String riepilogoCliente(Cliente? cliente, ProgettoConAcconti pc) {
  final p = pc.progetto;
  final nome = cliente?.nomeBreve ?? '';
  final ordinati = [...pc.acconti]..sort((a, b) => a.data.compareTo(b.data));
  var lista = ordinati
      .map((a) => '• ${dataBreve(a.data)}: *${euro(a.importo)}*${a.note.trim().isNotEmpty ? ' — ${a.note}' : ''}')
      .join('\n');
  if (lista.trim().isEmpty) lista = 'Nessun acconto registrato';
  final b = StringBuffer()
    ..write('Ciao $nome! 👋\n\n')
    ..write('Ecco il riepilogo per *${p.nome}*:\n\n')
    ..write('💰 *Totale progetto:* ${euro(p.totale)}\n')
    ..write('✅ *Totale pagato:* ${euro(pc.totalePagato)}\n')
    ..write('⏳ *Residuo:* ${euro(pc.residuo)}\n\n')
    ..write('📋 *Acconti ricevuti:*\n$lista\n\n');
  if (p.dataInizio > 0) b.write('📅 Inizio: ${dataBreve(p.dataInizio)}\n');
  if (p.dataFine > 0) b.write('🏁 Fine: ${dataBreve(p.dataFine)}\n');
  b.write('\nGrazie per la fiducia! 🙏');
  return b.toString();
}

/// Testo del tasto WhatsApp nella scheda segnalatore, in base allo stato.
String etichettaWhatsAppSegnalatore(StatoProvvigione s) => switch (s) {
      StatoProvvigione.daMaturare => 'Ringrazia',
      StatoProvvigione.lavoroFinito => 'Avvisa: compenso pronto',
      StatoProvvigione.pagata => 'Conferma pagamento',
    };

int _ultimaVariante = -1;

/// Messaggio per il segnalatore, a caso tra 5 varianti per stato (mai la stessa due volte di fila).
String messaggioSegnalatore(
    StatoProvvigione stato, String nomeSegnalatore, String nomeLavoro, String? nomeCliente, double provvigione) {
  final nome = nomeSegnalatore.trim().split(' ').first;
  final lavoro = '*$nomeLavoro*';
  final compenso = provvigione > 0 ? euro(provvigione) : null;
  final di = compenso != null ? ' di *$compenso*' : '';
  final chi = (nomeCliente != null && nomeCliente.trim().isNotEmpty) ? '*$nomeCliente*' : 'questo cliente';
  String blocco(String etichetta, String riga) => compenso != null ? '💶 *$etichetta* $compenso\n$riga\n\n' : '';

  final varianti = switch (stato) {
    StatoProvvigione.daMaturare => [
        'Ciao $nome! 👋\n\n'
            'Volevo ringraziarti per avermi presentato $chi: lavoro $lavoro preso 🙏\n\n'
            '${blocco('Il tuo compenso:', 'Lo riceverai alla fine del lavoro, quando il progetto sarà concluso e saldato. Ti aggiorno io appena è tutto pronto.')}'
            'Per altri lavori sono a disposizione, pensa pure a me 😉\n\n'
            'Grazie ancora, a presto!',
        'Ciao $nome! 😊\n\n'
            'Grazie mille per avermi messo in contatto con $chi: il lavoro $lavoro è partito 🚀\n\n'
            '${blocco('Il tuo compenso:', 'Te lo giro a fine lavoro, appena il progetto è chiuso e saldato. Ti tengo aggiornato!')}'
            'Se ti capita qualcun altro, io ci sono 💪\n\n'
            'A presto!',
        'Ehi $nome! 👋\n\n'
            'Ti scrivo per dirti grazie: $chi mi ha affidato il lavoro $lavoro e il merito è tuo 🙌\n\n'
            '${blocco('Per te:', 'Ti arriverà a fine lavoro, quando tutto sarà concluso e saldato.')}'
            'Se hai altri contatti, pensa pure a me 😉\n\n'
            'Grazie ancora!',
        'Ciao $nome! 🙂\n\n'
            'Volevo farti sapere che il lavoro $lavoro con $chi è confermato ✅ Grazie per la presentazione!\n\n'
            '${blocco('Il tuo compenso:', 'Lo riceverai a lavoro concluso e saldato, ti avviso io.')}'
            'Per qualsiasi altro lavoro sono a disposizione 🤝\n\n'
            'Un saluto!',
        'Ciao $nome, come va? ☺️\n\n'
            'Grazie di cuore per avermi presentato $chi: abbiamo avviato il lavoro $lavoro 🙏\n\n'
            '${blocco('Il tuo compenso:', 'Te lo riconosco a fine lavoro, quando il progetto sarà concluso e saldato.')}'
            'Se conosci qualcuno a cui serve un lavoro simile, fai pure il mio nome 😉\n\n'
            'Grazie ancora, a presto!',
      ],
    StatoProvvigione.lavoroFinito => [
        'Ciao $nome! 👋\n\n'
            'Il lavoro $lavoro è concluso ✅\n\n'
            'Il tuo compenso$di 💶 è pronto\nContattami appena puoi.\n\n'
            'Grazie ancora per la fiducia: se ti capita qualcun altro a cui serve una mano, sai dove trovarmi 🤝\n\n'
            'A presto!',
        'Ciao $nome! 😊\n\n'
            'Ti aggiorno: il lavoro $lavoro è finito ✅\n\n'
            'Il tuo compenso$di 💶 è pronto.\nSentiamoci quando puoi così ci organizziamo.\n\n'
            'Grazie ancora per avermi presentato $chi 🙏\n\n'
            'A presto!',
        'Ehi $nome! 👋\n\n'
            'Buone notizie: il lavoro $lavoro è concluso 🎉\n\n'
            'Il tuo compenso$di 💶 ti aspetta!\nFammi sapere quando ci possiamo sentire.\n\n'
            'Se ti capita qualcun altro a cui serve una mano, io ci sono 🤝\n\n'
            'A presto!',
        'Ciao $nome! 🙂\n\n'
            'Abbiamo chiuso il lavoro $lavoro ✅\n\n'
            'Il tuo compenso$di 💶 è pronto, contattami appena puoi.\n\n'
            'Grazie ancora per la fiducia e per la presentazione 🙏\n\n'
            'Un saluto!',
        'Ciao $nome, come va? ☺️\n\n'
            'Il lavoro $lavoro è concluso ✅ e come promesso il tuo compenso$di 💶 è pronto.\n'
            'Scrivimi o chiamami appena puoi.\n\n'
            'Per altri lavori sono sempre a disposizione, pensa pure a me 😉\n\n'
            'A presto!',
      ],
    StatoProvvigione.pagata => [
        'Ciao $nome! 👋\n\n'
            'Ti ho appena pagato il compenso$di per il lavoro $lavoro 💶✅\n'
            'Quando puoi controlla e fammi sapere se è tutto a posto.\n\n'
            'Grazie ancora per la fiducia, per altri lavori pensa pure a me 😉\n\n'
            'A presto!',
        'Ciao $nome! 😊\n\n'
            'Fatto! Il tuo compenso$di per il lavoro $lavoro è stato pagato 💶\n'
            'Fammi sapere quando lo ricevi.\n\n'
            'Grazie ancora per avermi presentato $chi 🙏\n\n'
            'A presto!',
        'Ehi $nome! 👋\n\n'
            'Ti confermo il pagamento del tuo compenso$di per il lavoro $lavoro ✅\n\n'
            'È stato un piacere lavorare grazie a te: se ti capita qualcun altro, io ci sono 🤝\n\n'
            'Un saluto!',
        'Ciao $nome! 🙂\n\n'
            'Come promesso ti ho pagato il compenso$di per il lavoro $lavoro 💶\n'
            'Controlla quando puoi e dimmi se è tutto ok.\n\n'
            'Per altri lavori sono a disposizione 😉\n\n'
            'Grazie ancora!',
        'Ciao $nome, come va? ☺️\n\n'
            'Ti scrivo per dirti che il tuo compenso$di per il lavoro $lavoro è stato pagato ✅\n\n'
            'Grazie di cuore per la fiducia, alla prossima! 🤝',
      ],
  };
  var indice = Random().nextInt(varianti.length);
  if (indice == _ultimaVariante) indice = (indice + 1) % varianti.length;
  _ultimaVariante = indice;
  return varianti[indice];
}
