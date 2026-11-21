package tg.zeroperte.app

import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Zéro Perte : petit canal natif pour les informations du téléphone,
 * sans bibliothèque supplémentaire (APK plus léger).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tg.zeroperte/telephone")
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "infos" -> resultat.success(infosTelephone())
                    else -> resultat.notImplemented()
                }
            }
    }

    private fun infosTelephone(): Map<String, Any> {
        val stat = StatFs(Environment.getDataDirectory().path)
        val libreMo = stat.availableBytes / (1024L * 1024L)
        return mapOf(
            "androidSdk" to Build.VERSION.SDK_INT,
            "androidVersion" to (Build.VERSION.RELEASE ?: ""),
            "fabricant" to (Build.MANUFACTURER ?: ""),
            "modele" to (Build.MODEL ?: ""),
            "servicesGoogle" to paquetInstalle("com.google.android.gms"),
            "espaceLibreMo" to libreMo,
        )
    }

    private fun paquetInstalle(nom: String): Boolean = try {
        packageManager.getPackageInfo(nom, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
