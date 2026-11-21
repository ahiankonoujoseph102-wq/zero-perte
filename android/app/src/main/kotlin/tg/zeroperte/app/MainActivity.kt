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
import androidx.core.content.FileProvider
import java.io.File
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
                    "partagerImage" -> resultat.success(
                        partagerImage(
                            appel.argument<ByteArray>("png"),
                            appel.argument<String>("texte") ?: "",
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

    /**
     * Partage une image (reçu) : directement dans WhatsApp s'il est installé
     * (ou WhatsApp Business), sinon par le menu de partage d'Android.
     * Renvoie "whatsapp", "autre" ou "echec".
     */
    private fun partagerImage(png: ByteArray?, texte: String): String {
        if (png == null) return "echec"
        return try {
            val dossier = File(cacheDir, "recus").apply { mkdirs() }
            dossier.listFiles()?.forEach { it.delete() } // un seul reçu à la fois
            val fichier = File(dossier, "recu-${System.currentTimeMillis()}.png")
            fichier.writeBytes(png)
            val uri = FileProvider.getUriForFile(this, "$packageName.fichiers", fichier)
            val intention = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                if (texte.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, texte)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val whatsapp = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { paquetInstalle(it) }
            if (whatsapp != null) {
                startActivity(intention.setPackage(whatsapp))
                "whatsapp"
            } else {
                startActivity(Intent.createChooser(intention, "Envoyer le reçu"))
                "autre"
            }
        } catch (e: Exception) {
            "echec"
        }
    }

    private fun paquetInstalle(nom: String): Boolean = try {
        packageManager.getPackageInfo(nom, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
