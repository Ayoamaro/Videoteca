package io.github.ayoamaro.videoteca

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// La app de Android. Además de Flutter, solo tiene el canal
// «videoteca/sistema» para pedirle cosas al móvil sin usar plugins
// (ver lib/disco/abrir_enlace.dart).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "videoteca/sistema")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    // Abre una web (FilmAffinity, IMDb…) con el navegador o
                    // la app que el móvil tenga para ella.
                    "abrir" -> {
                        val direccion = llamada.arguments as? String
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(direccion)))
                            resultado.success(true)
                        } catch (e: ActivityNotFoundException) {
                            resultado.success(false)
                        }
                    }
                    else -> resultado.notImplemented()
                }
            }
    }
}
