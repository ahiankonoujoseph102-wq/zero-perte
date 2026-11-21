package tg.zeroperte.app

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
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
                    "creerRaccourci" -> resultat.success(
                        creerRaccourci(
                            appel.argument<String>("nom") ?: "Zéro Perte",
                            appel.argument<ByteArray>("png"),
                        )
                    )
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

    /** Raccourci « boutique » sur l'écran d'accueil, avec le logo et le nom de la boutique. */
    private fun creerRaccourci(nom: String, png: ByteArray?): Boolean {
        val gestionnaire = getSystemService(ShortcutManager::class.java) ?: return false
        if (!gestionnaire.isRequestPinShortcutSupported || png == null) return false
        val image = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return false
        val intention = Intent(this, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
        val info = ShortcutInfo.Builder(this, "boutique")
            .setShortLabel(nom.take(25))
            .setLongLabel(nom.take(50))
            .setIcon(Icon.createWithBitmap(image))
            .setIntent(intention)
            .build()
        return gestionnaire.requestPinShortcut(info, null)
    }

    private fun paquetInstalle(nom: String): Boolean = try {
        packageManager.getPackageInfo(nom, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
