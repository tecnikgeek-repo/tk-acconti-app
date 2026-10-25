// Euro e date come nella versione Kotlin e nel plugin: «44.750 €» se intero, «1.234,56 €» con i decimali,
// date «5 mag 2026», ISO «yyyy-MM-dd» per il JSON.

const _mesiBrevi = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];

String _migliaia(String cifre) {
  final b = StringBuffer();
  for (var i = 0; i < cifre.length; i++) {
    if (i > 0 && (cifre.length - i) % 3 == 0) b.write('.');
    b.write(cifre[i]);
  }
  return b.toString();
}

/// «44.750 €» se intero, «1.234,56 €» se ha decimali (spazio non separabile prima del simbolo).
String euro(double v) {
  final negativo = v < 0;
  final a = v.abs();
  final centesimi = (a * 100).round();
  final interi = centesimi ~/ 100;
  final dec = centesimi % 100;
  var t = _migliaia('$interi');
  if (a % 1 != 0) t = '$t,${dec.toString().padLeft(2, '0')}';
  return '${negativo ? '-' : ''}$t €';
}

DateTime _dt(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

/// «5 mag 2026», «—» se la data non c'è.
String dataBreve(int ms) {
  if (ms <= 0) return '—';
  final d = _dt(ms);
  return '${d.day} ${_mesiBrevi[d.month - 1]} ${d.year}';
}

/// «17 set 2026, 18:42»
String dataOra(int ms) {
  if (ms <= 0) return '—';
  final d = _dt(ms);
  return '${dataBreve(ms)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// «yyyy-MM-dd» per il JSON compatibile col plugin; vuota se la data non c'è.
String dataIso(int ms) {
  if (ms <= 0) return '';
  final d = _dt(ms);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// «yyyy-MM-dd» → millisecondi (mezzanotte locale), 0 se vuota o non valida.
int daIso(String s) {
  final m = RegExp(r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m == null) return 0;
  final a = int.parse(m.group(1)!), me = int.parse(m.group(2)!), g = int.parse(m.group(3)!);
  if (me < 1 || me > 12 || g < 1 || g > 31) return 0;
  return DateTime(a, me, g).millisecondsSinceEpoch;
}

int inizioGiornata(int ms) {
  final d = _dt(ms);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

int oggi() => inizioGiornata(DateTime.now().millisecondsSinceEpoch);

/// Importo scritto a mano: «1.234,56», «1234,56», «1234.56», «1.500 €» → numero.
double leggiImporto(String s) {
  var t = s.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(' ', '');
  if (t.isEmpty) return 0;
  final virgola = t.contains(','), punto = t.contains('.');
  if (virgola && punto) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (virgola) {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t) ?? 0;
}

/// Importo nel campo di modifica: intero senza decimali, altrimenti con la virgola.
String perCampo(double v) {
  if (v % 1 == 0) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceAll('.', ',');
}
