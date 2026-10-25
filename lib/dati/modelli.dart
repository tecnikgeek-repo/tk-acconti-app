// Modelli di tk-acconti: stesse tabelle e stesse regole della versione Kotlin (e del plugin WordPress).
import 'dart:math';

int adesso() => DateTime.now().millisecondsSinceEpoch;

/// Identificativo condiviso col sito: 16 caratteri esadecimali.
String nuovoUid() {
  final r = Random.secure();
  const cifre = '0123456789abcdef';
  return List.generate(16, (_) => cifre[r.nextInt(16)]).join();
}

bool _b(Object? v) => v == 1 || v == true;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => (v as String?) ?? '';

class Cliente {
  Cliente({
    this.id = 0,
    this.uid = '',
    this.nome = '',
    this.nomeWA = '',
    this.telefono = '',
    this.email = '',
    this.note = '',
    this.daSaldare = false,
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? adesso(),
        updatedAt = updatedAt ?? adesso();

  final int id;
  final String uid;

  /// Nome completo mostrato in lista (es. «Mario Rossi»).
  final String nome;

  /// Nome usato nel messaggio WhatsApp (es. «Mario»).
  final String nomeWA;
  final String telefono, email, note;

  /// «Da saldare» messo a mano: ha la precedenza su tutto nella classificazione.
  final bool daSaldare;
  final int createdAt, updatedAt;

  factory Cliente.daRiga(Map<String, Object?> r) => Cliente(
        id: _i(r['id']),
        uid: _s(r['uid']),
        nome: _s(r['nome']),
        nomeWA: _s(r['nomeWA']),
        telefono: _s(r['telefono']),
        email: _s(r['email']),
        note: _s(r['note']),
        daSaldare: _b(r['daSaldare']),
        createdAt: _i(r['createdAt']),
        updatedAt: _i(r['updatedAt']),
      );

  Map<String, Object?> riga() => {
        if (id > 0) 'id': id,
        'uid': uid,
        'nome': nome,
        'nomeWA': nomeWA,
        'telefono': telefono,
        'email': email,
        'note': note,
        'daSaldare': daSaldare ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Cliente copia({
    int? id,
    String? uid,
    String? nome,
    String? nomeWA,
    String? telefono,
    String? email,
    String? note,
    bool? daSaldare,
    int? createdAt,
    int? updatedAt,
  }) =>
      Cliente(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        nome: nome ?? this.nome,
        nomeWA: nomeWA ?? this.nomeWA,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        note: note ?? this.note,
        daSaldare: daSaldare ?? this.daSaldare,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Nome per WhatsApp: quello indicato, altrimenti la prima parola del nome.
  String get nomeBreve => nomeWA.trim().isNotEmpty ? nomeWA.trim() : nome.trim().split(' ').first;
}

class Progetto {
  Progetto({
    this.id = 0,
    this.uid = '',
    this.clienteId = 0,
    this.nome = '',
    this.url = '',
    this.totale = 0,
    this.dataInizio = 0,
    this.dataFine = 0,
    this.note = '',
    this.presentatore = '',
    this.presentatoreTel = '',
    this.provvigione = 0,
    this.provvigionePagata = false,
    this.segnalatoreId = 0,
    this.lavoroFinito = false,
    this.provvigionePagataIl = 0,
    int? createdAt,
    this.updatedAt = 0,
  }) : createdAt = createdAt ?? adesso();

  final int id;
  final String uid;
  final int clienteId;
  final String nome, url;

  /// Totale concordato del lavoro in euro.
  final double totale;

  /// Date in millisecondi; 0 = non impostata.
  final int dataInizio, dataFine;
  final String note;

  /// Chi ha presentato il lavoro (copiato dal segnalatore, per il JSON del plugin).
  final String presentatore, presentatoreTel;
  final double provvigione;
  final bool provvigionePagata;

  /// Segnalatore collegato, 0 = nessuno.
  final int segnalatoreId;

  /// Lavoro segnato come finito a mano (anche se il cliente non ha ancora saldato).
  final bool lavoroFinito;
  final int provvigionePagataIl;
  final int createdAt, updatedAt;

  factory Progetto.daRiga(Map<String, Object?> r) => Progetto(
        id: _i(r['id']),
        uid: _s(r['uid']),
        clienteId: _i(r['clienteId']),
        nome: _s(r['nome']),
        url: _s(r['url']),
        totale: _d(r['totale']),
        dataInizio: _i(r['dataInizio']),
        dataFine: _i(r['dataFine']),
        note: _s(r['note']),
        presentatore: _s(r['presentatore']),
        presentatoreTel: _s(r['presentatoreTel']),
        provvigione: _d(r['provvigione']),
        provvigionePagata: _b(r['provvigionePagata']),
        segnalatoreId: _i(r['segnalatoreId']),
        lavoroFinito: _b(r['lavoroFinito']),
        provvigionePagataIl: _i(r['provvigionePagataIl']),
        createdAt: _i(r['createdAt']),
        updatedAt: _i(r['updatedAt']),
      );

  Map<String, Object?> riga() => {
        if (id > 0) 'id': id,
        'uid': uid,
        'clienteId': clienteId,
        'nome': nome,
        'url': url,
        'totale': totale,
        'dataInizio': dataInizio,
        'dataFine': dataFine,
        'note': note,
        'presentatore': presentatore,
        'presentatoreTel': presentatoreTel,
        'provvigione': provvigione,
        'provvigionePagata': provvigionePagata ? 1 : 0,
        'segnalatoreId': segnalatoreId,
        'lavoroFinito': lavoroFinito ? 1 : 0,
        'provvigionePagataIl': provvigionePagataIl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Progetto copia({
    int? id,
    String? uid,
    int? clienteId,
    String? nome,
    String? url,
    double? totale,
    int? dataInizio,
    int? dataFine,
    String? note,
    String? presentatore,
    String? presentatoreTel,
    double? provvigione,
    bool? provvigionePagata,
    int? segnalatoreId,
    bool? lavoroFinito,
    int? provvigionePagataIl,
    int? createdAt,
    int? updatedAt,
  }) =>
      Progetto(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        clienteId: clienteId ?? this.clienteId,
        nome: nome ?? this.nome,
        url: url ?? this.url,
        totale: totale ?? this.totale,
        dataInizio: dataInizio ?? this.dataInizio,
        dataFine: dataFine ?? this.dataFine,
        note: note ?? this.note,
        presentatore: presentatore ?? this.presentatore,
        presentatoreTel: presentatoreTel ?? this.presentatoreTel,
        provvigione: provvigione ?? this.provvigione,
        provvigionePagata: provvigionePagata ?? this.provvigionePagata,
        segnalatoreId: segnalatoreId ?? this.segnalatoreId,
        lavoroFinito: lavoroFinito ?? this.lavoroFinito,
        provvigionePagataIl: provvigionePagataIl ?? this.provvigionePagataIl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Acconto {
  Acconto({
    this.id = 0,
    this.uid = '',
    this.progettoId = 0,
    this.importo = 0,
    int? data,
    this.note = '',
    int? createdAt,
    this.updatedAt = 0,
  })  : data = data ?? adesso(),
        createdAt = createdAt ?? adesso();

  final int id;
  final String uid;
  final int progettoId;
  final double importo;

  /// Data dell'acconto in millisecondi.
  final int data;
  final String note;
  final int createdAt, updatedAt;

  factory Acconto.daRiga(Map<String, Object?> r) => Acconto(
        id: _i(r['id']),
        uid: _s(r['uid']),
        progettoId: _i(r['progettoId']),
        importo: _d(r['importo']),
        data: _i(r['data']),
        note: _s(r['note']),
        createdAt: _i(r['createdAt']),
        updatedAt: _i(r['updatedAt']),
      );

  Map<String, Object?> riga() => {
        if (id > 0) 'id': id,
        'uid': uid,
        'progettoId': progettoId,
        'importo': importo,
        'data': data,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Acconto copia({
    int? id,
    String? uid,
    int? progettoId,
    double? importo,
    int? data,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) =>
      Acconto(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        progettoId: progettoId ?? this.progettoId,
        importo: importo ?? this.importo,
        data: data ?? this.data,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Chi ti presenta i clienti: anagrafica unica, collegata ai progetti con segnalatoreId.
class Segnalatore {
  Segnalatore({
    this.id = 0,
    this.uid = '',
    this.nome = '',
    this.telefono = '',
    this.note = '',
    int? createdAt,
    this.updatedAt = 0,
  }) : createdAt = createdAt ?? adesso();

  final int id;
  final String uid, nome, telefono, note;
  final int createdAt, updatedAt;

  factory Segnalatore.daRiga(Map<String, Object?> r) => Segnalatore(
        id: _i(r['id']),
        uid: _s(r['uid']),
        nome: _s(r['nome']),
        telefono: _s(r['telefono']),
        note: _s(r['note']),
        createdAt: _i(r['createdAt']),
        updatedAt: _i(r['updatedAt']),
      );

  Map<String, Object?> riga() => {
        if (id > 0) 'id': id,
        'uid': uid,
        'nome': nome,
        'telefono': telefono,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Segnalatore copia({int? id, String? uid, String? nome, String? telefono, String? note, int? createdAt, int? updatedAt}) =>
      Segnalatore(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        nome: nome ?? this.nome,
        telefono: telefono ?? this.telefono,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Traccia di un record eliminato sul telefono: fa sparire lo stesso record anche sul sito.
class Eliminato {
  Eliminato(this.tipo, this.uid, this.at);

  /// «cliente» | «sito» | «acconto» | «segnalatore»
  final String tipo;
  final String uid;
  final int at;
}

// ───────────────────────── viste composte ─────────────────────────

enum CategoriaCliente { inCorso, daSaldare, concluso }

enum StatoProvvigione {
  daMaturare('Da maturare'),
  lavoroFinito('Lavoro finito'),
  pagata('Pagata');

  const StatoProvvigione(this.etichetta);
  final String etichetta;
}

class ProgettoConAcconti {
  ProgettoConAcconti(this.progetto, this.acconti);

  final Progetto progetto;
  final List<Acconto> acconti;

  double get totalePagato => acconti.fold(0.0, (s, a) => s + a.importo);
  double get residuo => progetto.totale - totalePagato;
  int get percentuale => progetto.totale > 0 ? (totalePagato / progetto.totale * 100).truncate().clamp(0, 100) : 0;

  /// La nota «PAGATO» chiude il progetto anche con un residuo (scelta manuale).
  bool get pagatoManuale => progetto.note.contains('PAGATO');
  bool get concluso => pagatoManuale || (progetto.totale > 0 && residuo <= 0);

  /// Pagata > lavoro finito (a mano o cliente saldato) > da maturare.
  StatoProvvigione get statoProvvigione {
    if (progetto.provvigionePagata) return StatoProvvigione.pagata;
    if (progetto.lavoroFinito || concluso) return StatoProvvigione.lavoroFinito;
    return StatoProvvigione.daMaturare;
  }
}

class SegnalatoreConProgetti {
  SegnalatoreConProgetti(this.segnalatore, this.progetti);

  final Segnalatore segnalatore;
  final List<ProgettoConAcconti> progetti;

  double get totaleProvvigioni => progetti.fold(0.0, (s, p) => s + p.progetto.provvigione);
  double get pagato => progetti
      .where((p) => p.statoProvvigione == StatoProvvigione.pagata)
      .fold(0.0, (s, p) => s + p.progetto.provvigione);

  /// Ancora da pagare (lavori in corso + finiti).
  double get daPagare => totaleProvvigioni - pagato;

  /// Da pagare subito: lavori finiti con provvigione non ancora pagata.
  double get pronto => progetti
      .where((p) => p.statoProvvigione == StatoProvvigione.lavoroFinito)
      .fold(0.0, (s, p) => s + p.progetto.provvigione);
}

class ClienteCompleto {
  ClienteCompleto(this.cliente, this.progetti);

  final Cliente cliente;
  final List<ProgettoConAcconti> progetti;

  double get totale => progetti.fold(0.0, (s, p) => s + p.progetto.totale);
  double get incassato => progetti.fold(0.0, (s, p) => s + p.totalePagato);
  double get residuo => totale - incassato;

  /// Stessa regola del plugin: «da saldare» a mano → DA_SALDARE; nessun progetto → IN_CORSO;
  /// tutti i progetti conclusi → CONCLUSO; altrimenti IN_CORSO.
  CategoriaCliente get categoria {
    if (cliente.daSaldare) return CategoriaCliente.daSaldare;
    if (progetti.isEmpty) return CategoriaCliente.inCorso;
    return progetti.every((p) => p.concluso) ? CategoriaCliente.concluso : CategoriaCliente.inCorso;
  }

  /// Data dell'ultimo acconto (per ordinare), 0 se nessuno.
  int get ultimoAcconto {
    var m = 0;
    for (final p in progetti) {
      for (final a in p.acconti) {
        if (a.data > m) m = a.data;
      }
    }
    return m;
  }
}
