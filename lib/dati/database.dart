// Database di tk-acconti: è LO STESSO FILE della versione Kotlin (tk_acconti.db, schema 4 di Room),
// così chi aggiorna ritrova clienti, progetti, acconti e segnalatori senza fare niente.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const nomeDatabase = 'tk_acconti.db';
const versioneDatabase = 4;

/// Schema identico a quello creato da Room alla versione 4 (per chi installa da zero).
const _schema = [
  'CREATE TABLE IF NOT EXISTS clienti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, uid TEXT NOT NULL DEFAULT \'\', '
      'nome TEXT NOT NULL, nomeWA TEXT NOT NULL, telefono TEXT NOT NULL, email TEXT NOT NULL, note TEXT NOT NULL, '
      'daSaldare INTEGER NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS progetti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, uid TEXT NOT NULL DEFAULT \'\', '
      'clienteId INTEGER NOT NULL, nome TEXT NOT NULL, url TEXT NOT NULL, totale REAL NOT NULL, '
      'dataInizio INTEGER NOT NULL, dataFine INTEGER NOT NULL, note TEXT NOT NULL, '
      'presentatore TEXT NOT NULL DEFAULT \'\', presentatoreTel TEXT NOT NULL DEFAULT \'\', '
      'provvigione REAL NOT NULL DEFAULT 0, provvigionePagata INTEGER NOT NULL DEFAULT 0, '
      'segnalatoreId INTEGER NOT NULL DEFAULT 0, lavoroFinito INTEGER NOT NULL DEFAULT 0, '
      'provvigionePagataIl INTEGER NOT NULL DEFAULT 0, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL DEFAULT 0, '
      'FOREIGN KEY(clienteId) REFERENCES clienti(id) ON UPDATE NO ACTION ON DELETE CASCADE)',
  'CREATE INDEX IF NOT EXISTS index_progetti_clienteId ON progetti (clienteId)',
  'CREATE TABLE IF NOT EXISTS acconti (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, uid TEXT NOT NULL DEFAULT \'\', '
      'progettoId INTEGER NOT NULL, importo REAL NOT NULL, data INTEGER NOT NULL, note TEXT NOT NULL, '
      'createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL DEFAULT 0, '
      'FOREIGN KEY(progettoId) REFERENCES progetti(id) ON UPDATE NO ACTION ON DELETE CASCADE)',
  'CREATE INDEX IF NOT EXISTS index_acconti_progettoId ON acconti (progettoId)',
  'CREATE TABLE IF NOT EXISTS segnalatori (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, uid TEXT NOT NULL DEFAULT \'\', '
      'nome TEXT NOT NULL, telefono TEXT NOT NULL, note TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS eliminati (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'tipo TEXT NOT NULL, uid TEXT NOT NULL, at INTEGER NOT NULL)',
];

/// Le migrazioni della versione Kotlin, per un telefono rimasto a una versione vecchia.
Future<void> _migra(Database db, int da) async {
  if (da < 2) {
    // 1 → 2 (1.2.0): «Presentato da» + updatedAt
    await db.execute("ALTER TABLE progetti ADD COLUMN presentatore TEXT NOT NULL DEFAULT ''");
    await db.execute("ALTER TABLE progetti ADD COLUMN presentatoreTel TEXT NOT NULL DEFAULT ''");
    await db.execute('ALTER TABLE progetti ADD COLUMN provvigione REAL NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE progetti ADD COLUMN provvigionePagata INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE progetti ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE acconti ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
  }
  if (da < 3) {
    // 2 → 3 (1.3.0): anagrafica segnalatori ricavata dai nomi «Presentato da»
    await db.execute('CREATE TABLE IF NOT EXISTS segnalatori (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
        'nome TEXT NOT NULL, telefono TEXT NOT NULL, note TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)');
    await db.execute('ALTER TABLE progetti ADD COLUMN segnalatoreId INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE progetti ADD COLUMN lavoroFinito INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE progetti ADD COLUMN provvigionePagataIl INTEGER NOT NULL DEFAULT 0');
    final ora = DateTime.now().millisecondsSinceEpoch;
    await db.execute('INSERT INTO segnalatori (nome, telefono, note, createdAt, updatedAt) '
        "SELECT TRIM(presentatore), MAX(TRIM(presentatoreTel)), '', $ora, $ora "
        "FROM progetti WHERE TRIM(presentatore) <> '' GROUP BY LOWER(TRIM(presentatore))");
    await db.execute('UPDATE progetti SET segnalatoreId = (SELECT s.id FROM segnalatori s '
        "WHERE LOWER(s.nome) = LOWER(TRIM(progetti.presentatore))) WHERE TRIM(presentatore) <> ''");
  }
  if (da < 4) {
    // 3 → 4 (1.4.0): uid condiviso col sito + tracce delle eliminazioni
    for (final t in ['clienti', 'progetti', 'acconti', 'segnalatori']) {
      await db.execute("ALTER TABLE $t ADD COLUMN uid TEXT NOT NULL DEFAULT ''");
      await db.execute("UPDATE $t SET uid = lower(hex(randomblob(8))) WHERE uid = ''");
    }
    await db.execute('CREATE TABLE IF NOT EXISTS eliminati (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
        'tipo TEXT NOT NULL, uid TEXT NOT NULL, at INTEGER NOT NULL)');
  }
}

/// Apre (o crea) il database. [percorso] serve ai test; di serie è quello della vecchia app.
Future<Database> apriDatabase({String? percorso, DatabaseFactory? fabbrica}) async {
  final f = fabbrica ?? databaseFactory;
  final file = percorso ?? p.join(await f.getDatabasesPath(), nomeDatabase);
  return f.openDatabase(
    file,
    options: OpenDatabaseOptions(
      version: versioneDatabase,
      // come Room: le eliminazioni a cascata (cliente → progetti → acconti) le fa SQLite
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final s in _schema) {
          await db.execute(s);
        }
      },
      onUpgrade: (db, da, _) => _migra(db, da),
    ),
  );
}
