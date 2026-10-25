// Colori e pezzi propri di tk-acconti; testata, card, dialoghi, Informazioni e splash sono nel kit comune.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dati/modelli.dart';
import 'kit_tk.dart';

export 'kit_tk.dart';

const accento = Color(0xFF009BDF); // azzurro della prima tk-acconti
const accentoScuro = Color(0xFF0077B3);
const accentoTesto = Color(0xFF035A86);
const accentoChiaro = Color(0xFFDDF2FB);
const verdeChiaro = Color(0xFFDCFCE7);
const rossoChiaro = Color(0xFFFEE2E2);
const blu = Color(0xFF2E5BFF);
const bluChiaro = Color(0xFFE1E8FF);
const whatsapp = Color(0xFF25D366);

/// Simbolo di tk-acconti: portafoglio bianco.
Widget simboloAcconti(double lato) => Icon(Icons.account_balance_wallet_rounded, color: bianco, size: lato * .56);

const configAcconti = ConfigTk(
  nome: 'tk-acconti',
  motto: 'Acconti e clienti in tasca',
  descrizione: 'Acconti, clienti e segnalatori',
  accento: accento,
  accentoScuro: accentoScuro,
  simbolo: simboloAcconti,
  manifestUrl:
      'https://dl.dropboxusercontent.com/scl/fi/gb365e70riuca44x375nr/acconti-version.json?rlkey=9c0e15c0qhntc0ls84nmmpdyd',
);

const _coloriAvatar = [
  Color(0xFF2E5BFF), Color(0xFFE39A2E), Color(0xFF1FA971), Color(0xFF7C3AED),
  Color(0xFFD64545), Color(0xFF0E9AA7), Color(0xFFDB2777), Color(0xFF4F46E5),
];

/// Colore dell'avatar: stesso calcolo della versione Kotlin (hashCode di Java), quindi stesso colore di prima.
Color coloreAvatar(String nome) {
  if (nome.trim().isEmpty) return grigio500;
  var h = 0;
  for (final c in nome.toLowerCase().codeUnits) {
    h = (31 * h + c).toSigned(32);
  }
  return _coloriAvatar[h % _coloriAvatar.length];
}

/// Avatar a iniziali (al massimo due).
class Avatar extends StatelessWidget {
  const Avatar(this.nome, {super.key, this.lato = 42, this.raggio = 14});

  final String nome;
  final double lato, raggio;

  @override
  Widget build(BuildContext context) {
    final parole = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final iniziali = parole.map((p) => p.characters.first.toUpperCase()).join();
    return Container(
      width: lato,
      height: lato,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: coloreAvatar(nome), borderRadius: BorderRadius.circular(raggio)),
      child: Text(iniziali.isEmpty ? '?' : iniziali,
          style: TextStyle(color: bianco, fontWeight: FontWeight.w800, fontSize: lato * .36)),
    );
  }
}

/// Pillola con fondo chiaro e testo colorato.
class Badge2 extends StatelessWidget {
  const Badge2(this.testo, this.fondo, this.colore, {super.key});

  final String testo;
  final Color fondo, colore;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
        child: Text(testo.toUpperCase(),
            style: TextStyle(color: colore, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4)),
      );
}

Widget badgeCategoria(CategoriaCliente c) => switch (c) {
      CategoriaCliente.concluso => const Badge2('Concluso', verdeChiaro, verde),
      CategoriaCliente.inCorso => const Badge2('In corso', accentoChiaro, accentoTesto),
      CategoriaCliente.daSaldare => const Badge2('Da saldare', rossoChiaro, rosso),
    };

Widget badgeProvvigione(StatoProvvigione s) => switch (s) {
      StatoProvvigione.daMaturare => Badge2(s.etichetta, accentoChiaro, accentoTesto),
      StatoProvvigione.lavoroFinito => Badge2(s.etichetta, bluChiaro, blu),
      StatoProvvigione.pagata => Badge2(s.etichetta, verdeChiaro, verde),
    };

/// Colore dell'avanzamento: rosso se da saldare, verde se pagato tutto, altrimenti accento.
Color coloreAvanzamento(int percentuale, {bool daSaldare = false}) {
  if (daSaldare) return rosso;
  if (percentuale >= 100) return verde;
  return accento;
}

/// Barra sottile animata.
class BarraAvanzamento extends StatelessWidget {
  const BarraAvanzamento(this.percentuale, {super.key, this.colore = accento, this.altezza = 5});

  final int percentuale;
  final Color colore;
  final double altezza;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(altezza),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percentuale.clamp(0, 100) / 100),
          duration: const Duration(milliseconds: 600),
          builder: (_, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: altezza,
            color: colore,
            backgroundColor: grigio200,
          ),
        ),
      );
}

/// Anello d'avanzamento con la percentuale al centro.
class Anello extends StatelessWidget {
  const Anello(this.percentuale, {super.key, this.colore = accento, this.lato = 108, this.etichetta = 'pagato'});

  final int percentuale;
  final Color colore;
  final double lato;
  final String etichetta;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percentuale.clamp(0, 100) / 100),
        duration: const Duration(milliseconds: 800),
        builder: (_, v, _) => SizedBox(
          width: lato,
          height: lato,
          child: CustomPaint(
            painter: _PittoreAnello(v, colore),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${percentuale.clamp(0, 100)}%',
                    style: TextStyle(color: navy, fontSize: lato * .22, fontWeight: FontWeight.w800, letterSpacing: -.8)),
                Text(etichetta, style: const TextStyle(color: grigio500, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}

class _PittoreAnello extends CustomPainter {
  _PittoreAnello(this.valore, this.colore);

  final double valore;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    const spessore = 10.0;
    final r = Rect.fromLTWH(spessore / 2, spessore / 2, size.width - spessore, size.height - spessore);
    final base = Paint()
      ..color = grigio200
      ..style = PaintingStyle.stroke
      ..strokeWidth = spessore
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (valore > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * valore, false, base..color = colore);
  }

  @override
  bool shouldRepaint(covariant _PittoreAnello old) => old.valore != valore || old.colore != colore;
}

/// Cifra con etichetta sopra (fasce statistiche nelle card).
class Cifra extends StatelessWidget {
  const Cifra(this.valore, this.etichetta, {super.key, this.colore = navy, this.grande = false});

  final String valore, etichetta;
  final Color colore;
  final bool grande;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etichetta, style: const TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valore,
              maxLines: 1,
              style: TextStyle(
                  color: colore, fontSize: grande ? 18 : 17, fontWeight: FontWeight.w800, letterSpacing: -.4)),
        ),
      ]);
}

/// Etichetta + valore (contatti, note, date).
class Voce extends StatelessWidget {
  const Voce(this.etichetta, this.valore, {super.key, this.colore = navy});

  final String etichetta, valore;
  final Color colore;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etichetta, style: const TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w700)),
        Text(valore, style: TextStyle(color: colore, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]);
}

/// Riquadro «niente da mostrare» con icona.
class StatoVuoto extends StatelessWidget {
  const StatoVuoto(this.icona, this.titolo, this.sottotitolo, {super.key});

  final IconData icona;
  final String titolo, sottotitolo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: accentoChiaro, borderRadius: BorderRadius.circular(20)),
            child: Icon(icona, color: accentoScuro, size: 32),
          ),
          const SizedBox(height: 12),
          Text(titolo, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sottotitolo,
              textAlign: TextAlign.center, style: const TextStyle(color: grigio500, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Titolo di sezione con un contatore a destra («Progetti 3»).
class Sezione extends StatelessWidget {
  const Sezione(this.titolo, {super.key, this.destra});

  final String titolo;
  final String? destra;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
        child: Row(children: [
          Text(titolo, style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (destra != null)
            Text(destra!, style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Pulsante basso a tutta cella (azioni della scheda: «Segna da saldare», «Scrivi su WhatsApp»…).
class Tasto extends StatelessWidget {
  const Tasto(this.testo, {super.key, required this.colore, required this.fondo, required this.onTap, this.icona});

  final String testo;
  final Color colore, fondo;
  final VoidCallback onTap;
  final IconData? icona;

  @override
  Widget build(BuildContext context) => Material(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fondo == bianco ? grigio200 : fondo),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icona != null) ...[Icon(icona, color: colore, size: 17), const SizedBox(width: 6)],
              Flexible(
                child: Text(testo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colore, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      );
}

/// Pulsante flottante delle app TK.
Widget pulsanteNuovo(String testo, VoidCallback onTap) => FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: accento,
      foregroundColor: bianco,
      icon: const Icon(Icons.add_rounded),
      label: Text(testo.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
