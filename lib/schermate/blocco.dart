// Blocco con PIN (e impronta/volto) all'apertura, se impostato in Impostazioni.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../app.dart';
import '../tema.dart';

final _auth = LocalAuthentication();

Future<bool> biometriaDisponibile() async {
  try {
    return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}

class Blocco extends StatefulWidget {
  const Blocco({super.key, required this.child});

  final Widget child;

  @override
  State<Blocco> createState() => _BloccoState();
}

class _BloccoState extends State<Blocco> {
  late bool _sbloccata = !impostazioni.haPin;
  final _pin = TextEditingController();
  bool _errore = false;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    if (!_sbloccata && impostazioni.biometria) {
      biometriaDisponibile().then((si) {
        if (!mounted) return;
        setState(() => _bio = si);
        if (si) _provaBiometria();
      });
    }
  }

  Future<void> _provaBiometria() async {
    try {
      final ok = await _auth.authenticate(localizedReason: 'Sblocca tk-acconti', biometricOnly: true);
      if (ok && mounted) setState(() => _sbloccata = true);
    } catch (_) {
      // si usa il PIN
    }
  }

  void _sblocca() {
    if (impostazioni.verificaPin(_pin.text)) {
      setState(() => _sbloccata = true);
    } else {
      setState(() {
        _errore = true;
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sbloccata) return widget.child;
    return Scaffold(
      backgroundColor: navy,
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [navy, navy2, navy3], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(children: [
                const LogoTk(lato: 96),
                const SizedBox(height: 20),
                const Text('tk-acconti', style: TextStyle(color: bianco, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Inserisci il PIN per accedere',
                    style: TextStyle(color: grigio300, fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 26),
                CardTk(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(
                      controller: _pin,
                      autofocus: !_bio,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                      onChanged: (_) => setState(() => _errore = false),
                      onSubmitted: (_) => _pin.text.length >= 4 ? _sblocca() : null,
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorText: _errore ? 'PIN errato' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BottoneTk(
                        testo: 'Sblocca',
                        icona: Icons.lock_open_rounded,
                        onTap: _pin.text.length >= 4 ? _sblocca : null),
                    if (_bio) ...[
                      const SizedBox(height: 10),
                      BottoneTk(
                          testo: 'Usa impronta / volto', icona: Icons.fingerprint_rounded, chiaro: true, onTap: _provaBiometria),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
