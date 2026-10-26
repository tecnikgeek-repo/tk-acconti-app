package it.pietrodefilippis.tkacconti

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FragmentActivity: serve allo sblocco con impronta/volto (local_auth)
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TkAggiornamento.registra(flutterEngine, this)
    }
}
