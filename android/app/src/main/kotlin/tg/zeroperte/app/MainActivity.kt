package tg.zeroperte.app

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.media.MediaPlayer
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.content.FileProvider
import com.google.firebase.messaging.FirebaseMessaging
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.common.MlKitException
import com.google.zxing.integration.android.IntentIntegrator
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import android.Manifest
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
                    "partagerFichier" -> resultat.success(
                        partagerFichier(
                            appel.argument<ByteArray>("octets"),
                            appel.argument<String>("nom") ?: "sauvegarde.zps",
                        )
                    )
                    "notifications" -> resultat.success(
                        activerNotifications(
                            appel.argument<String>("cle"),
                            appel.argument<String>("appli"),
                            appel.argument<String>("projet"),
                            appel.argument<String>("expediteur"),
                            appel.argument<String>("sujet"),
                        )
                    )
                    // Ajout d'un vendeur : lecteur de QR code de Google Play
                    // services (aucune autorisation d'appareil photo, presque
                    // rien dans l'APK).
                    "scannerQr" -> scannerQr(resultat)
                    // 0.37.1 : lecteur de secours DANS l'application (ZXing),
                    // si celui des Services Google Play ne s'ouvre pas.
                    "scannerQrSecours" -> scannerQrSecours(resultat)
                    "lecteurPret" -> lecteurPret(resultat)
                    "lecteurPreparer" -> lecteurPreparer(resultat)
                    // Démonstration guidée : voix d'Afi (fichier MP3).
                    "jouerSon" -> jouerSon(appel.argument<String>("chemin"), resultat)
                    "arreterSon" -> {
                        arreterSon()
                        resultat.success(true)
                    }
                    else -> resultat.notImplemented()
                }
            }
    }

    // --- Lecteur de QR code (Google code scanner) ---
    // Le lecteur est un MODULE des Services Google Play, téléchargé à la
    // demande : avant la 0.35.2, le premier appel échouait (module pas encore
    // là) et l'application le prenait pour une panne définitive. Maintenant :
    // « lecteurPret » vérifie, « lecteurPreparer » demande l'installation
    // (urgente), et chaque erreur remonte avec son code exact.

    private fun clientScanner() = GmsBarcodeScanning.getClient(
        this,
        GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .enableAutoZoom()
            .build(),
    )

    /** Erreur vers Dart : code exact + d'où il vient (mlkit, api, install). */
    private fun erreurLecteur(resultat: MethodChannel.Result, e: Exception?) {
        when (e) {
            is MlKitException -> resultat.error(
                "lecteur", e.message, mapOf("source" to "mlkit", "code" to e.errorCode),
            )
            is ApiException -> resultat.error(
                "lecteur", e.message, mapOf("source" to "api", "code" to e.statusCode),
            )
            else -> resultat.error(
                "lecteur",
                "${e?.javaClass?.simpleName ?: "Erreur"} : ${e?.message ?: "inconnue"}",
                mapOf("source" to "autre", "code" to -1),
            )
        }
    }

    private fun scannerQr(resultat: MethodChannel.Result) {
        try {
            clientScanner().startScan()
                .addOnSuccessListener { code -> resultat.success(code.rawValue) }
                // La personne ferme le lecteur : pas une erreur.
                .addOnCanceledListener { resultat.success(null) }
                .addOnFailureListener { e ->
                    if (e is MlKitException && e.errorCode == MlKitException.CODE_SCANNER_CANCELLED) {
                        resultat.success(null)
                    } else {
                        erreurLecteur(resultat, e)
                    }
                }
        } catch (e: Exception) {
            erreurLecteur(resultat, e)
        }
    }

    // --- Lecteur de secours (ZXing, dans l'application) ---
    // Certains téléphones (Services Google Play modifiés ou incomplets) ne
    // peuvent pas ouvrir le lecteur de Google (« Code : -1 / INCONNU »). Ce
    // lecteur-ci ne dépend de rien : il utilise l'appareil photo directement
    // et demande lui-même l'autorisation.
    private var resultatSecours: MethodChannel.Result? = null

    private fun scannerQrSecours(resultat: MethodChannel.Result) {
        try {
            resultatSecours?.success(null)
            resultatSecours = resultat
            IntentIntegrator(this)
                .setDesiredBarcodeFormats(IntentIntegrator.QR_CODE)
                .setPrompt("Visez le QR code sur le téléphone du patron")
                .setOrientationLocked(false)
                .setBeepEnabled(false)
                .initiateScan()
        } catch (e: Exception) {
            resultatSecours = null
            resultat.error(
                "lecteur",
                "${e.javaClass.simpleName} : ${e.message ?: "inconnue"}",
                mapOf("source" to "secours", "code" to -2),
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val lu = IntentIntegrator.parseActivityResult(requestCode, resultCode, data)
        val r = resultatSecours
        if (lu != null && r != null) {
            resultatSecours = null
            // Fermé sans lire : contents nul (pas une erreur).
            r.success(lu.contents)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun lecteurPret(resultat: MethodChannel.Result) {
        try {
            ModuleInstall.getClient(this).areModulesAvailable(clientScanner())
                .addOnSuccessListener { r -> resultat.success(r.areModulesAvailable()) }
                .addOnFailureListener { e -> erreurLecteur(resultat, e) }
        } catch (e: Exception) {
            erreurLecteur(resultat, e)
        }
    }

    /** Installation URGENTE du module ; répond quand il est prêt (ou en échec). */
    private fun lecteurPreparer(resultat: MethodChannel.Result) {
        try {
            val client = ModuleInstall.getClient(this)
            var repondu = false
            fun repondre(action: () -> Unit) {
                if (!repondu) {
                    repondu = true
                    runOnUiThread(action)
                }
            }
            lateinit var ecoute: InstallStatusListener
            ecoute = InstallStatusListener { maj ->
                when (maj.installState) {
                    ModuleInstallStatusUpdate.InstallState.STATE_COMPLETED -> {
                        client.unregisterListener(ecoute)
                        repondre { resultat.success(true) }
                    }
                    ModuleInstallStatusUpdate.InstallState.STATE_FAILED,
                    ModuleInstallStatusUpdate.InstallState.STATE_CANCELED -> {
                        client.unregisterListener(ecoute)
                        repondre {
                            resultat.error(
                                "lecteur", "installation : état ${maj.installState}",
                                mapOf(
                                    "source" to "install",
                                    "code" to maj.errorCode,
                                    "etat" to maj.installState,
                                ),
                            )
                        }
                    }
                    else -> {}
                }
            }
            val demande = ModuleInstallRequest.newBuilder()
                .addApi(clientScanner())
                .setListener(ecoute)
                .build()
            client.installModules(demande)
                .addOnSuccessListener { r ->
                    if (r.areModulesAlreadyInstalled()) {
                        client.unregisterListener(ecoute)
                        repondre { resultat.success(true) }
                    }
                }
                .addOnFailureListener { e ->
                    client.unregisterListener(ecoute)
                    repondre { erreurLecteur(resultat, e) }
                }
        } catch (e: Exception) {
            erreurLecteur(resultat, e)
        }
    }

    // --- Voix de la démonstration (lecteur d'Android, sans bibliothèque) ---
    private var lecteur: MediaPlayer? = null
    private var resultatSon: MethodChannel.Result? = null

    /** Joue un fichier ; répond « vrai » à la fin de la lecture, « faux » si
     *  le fichier ne peut pas être lu (la démonstration prend alors la voix
     *  de synthèse du téléphone). */
    private fun jouerSon(chemin: String?, resultat: MethodChannel.Result) {
        arreterSon()
        if (chemin == null) {
            resultat.success(false)
            return
        }
        try {
            val m = MediaPlayer()
            m.setDataSource(chemin)
            m.setOnCompletionListener { finirSon(true) }
            m.setOnErrorListener { _, _, _ ->
                finirSon(false)
                true
            }
            m.prepare()
            lecteur = m
            resultatSon = resultat
            m.start()
        } catch (e: Exception) {
            lecteur?.release()
            lecteur = null
            resultat.success(false)
        }
    }

    private fun finirSon(ok: Boolean) {
        val r = resultatSon
        resultatSon = null
        lecteur?.release()
        lecteur = null
        r?.success(ok)
    }

    private fun arreterSon() {
        val r = resultatSon
        resultatSon = null
        try {
            lecteur?.stop()
        } catch (_: Exception) {
        }
        lecteur?.release()
        lecteur = null
        r?.success(false)
    }

    override fun onDestroy() {
        arreterSon()
        super.onDestroy()
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

    /** Partage un fichier de sauvegarde par le menu de partage (WhatsApp, Drive, Bluetooth…). */
    private fun partagerFichier(octets: ByteArray?, nom: String): String {
        if (octets == null) return "echec"
        return try {
            val dossier = File(cacheDir, "sauvegardes").apply { mkdirs() }
            dossier.listFiles()?.forEach { it.delete() }
            val fichier = File(dossier, nom.replace(Regex("[^A-Za-z0-9._-]"), "-"))
            fichier.writeBytes(octets)
            val uri = FileProvider.getUriForFile(this, "$packageName.fichiers", fichier)
            val intention = Intent(Intent.ACTION_SEND).apply {
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intention, "Garder la sauvegarde"))
            "autre"
        } catch (e: Exception) {
            "echec"
        }
    }

    /** Abonne ce téléphone (celui du patron) aux alertes graves de sa boutique. */
    private fun activerNotifications(
        cle: String?, appli: String?, projet: String?, expediteur: String?, sujet: String?,
    ): Boolean {
        if (cle.isNullOrEmpty() || appli.isNullOrEmpty() || projet.isNullOrEmpty() ||
            expediteur.isNullOrEmpty() || sujet.isNullOrEmpty()) return false
        getSharedPreferences(ZeroPerteApplication.PREFS, MODE_PRIVATE).edit()
            .putString("cle", cle).putString("appli", appli)
            .putString("projet", projet).putString("expediteur", expediteur)
            .apply()
        if (!ZeroPerteApplication.demarrerFirebase(this)) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
        return try {
            FirebaseMessaging.getInstance().isAutoInitEnabled = true
            FirebaseMessaging.getInstance().subscribeToTopic(sujet)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun paquetInstalle(nom: String): Boolean = try {
        packageManager.getPackageInfo(nom, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
