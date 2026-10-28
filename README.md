# tk-acconti per Android e iPhone

Acconti dei clienti sul telefono: clienti e progetti, acconti versati e saldo, segnalatori con la loro parte,
riepilogo al cliente su WhatsApp, blocco con PIN e impronta, copia di sicurezza e sincronizzazione facoltativa con
la pagina Acconti del tuo sito. Tutte le funzioni sono gratis, per tutti.

- **Piattaforme:** Android (APK) e iPhone.
- **Licenza:** software libero sotto [GNU AGPL-3.0](COPYING), fornito così com'è, senza alcuna garanzia.
- **Privacy:** i dati restano sul telefono; con la sincronizzazione vanno solo al sito che scegli tu. Le statistiche
  anonime (una volta al giorno: nome, versione, sistema e un codice casuale) partono solo se dici sì nel benvenuto
  o in Informazioni.

## Compilare dal sorgente

Serve [Flutter](https://flutter.dev) (versione indicata in `.github/workflows/android.yml`):

```
flutter pub get
flutter test
flutter build apk --release
```

Senza la variabile `ANDROID_KEYSTORE` l'APK si firma con la chiave di debug di Flutter.

Il nome «tk-acconti» e il logo non sono coperti dalla licenza (AGPL sez. 7): una versione modificata deve avere un
nome diverso.

© 2026 Pietro De Filippis (TecnikGeek) — [pietrodefilippis.it](https://pietrodefilippis.it)
