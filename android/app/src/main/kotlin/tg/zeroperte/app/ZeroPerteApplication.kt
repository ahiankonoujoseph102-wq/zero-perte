package tg.zeroperte.app

import android.app.Application
import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

/**
 * Démarre Firebase (notifications des alertes) avec les identifiants enregistrés
 * par l'application, même quand elle est fermée et qu'une notification arrive.
 */
class ZeroPerteApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        demarrerFirebase(this)
    }

    companion object {
        const val PREFS = "zp_firebase"

        fun demarrerFirebase(contexte: Context): Boolean {
            if (FirebaseApp.getApps(contexte).isNotEmpty()) return true
            val p = contexte.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val cle = p.getString("cle", null) ?: return false
            val appli = p.getString("appli", null) ?: return false
            val projet = p.getString("projet", null) ?: return false
            val expediteur = p.getString("expediteur", null) ?: return false
            return try {
                val options = FirebaseOptions.Builder()
                    .setApiKey(cle)
                    .setApplicationId(appli)
                    .setProjectId(projet)
                    .setGcmSenderId(expediteur)
                    .build()
                FirebaseApp.initializeApp(contexte, options)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
