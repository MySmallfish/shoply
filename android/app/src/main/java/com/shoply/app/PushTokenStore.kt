package com.shoply.app

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

object PushTokenStore {
    private const val PREFS = "shoply"
    private const val KEY = "fcmToken"
    private val db = FirebaseFirestore.getInstance()

    fun updateToken(context: Context, token: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, token)
            .apply()
        saveIfPossible(context)
    }

    fun sync(context: Context) {
        saveIfPossible(context)
    }

    private fun saveIfPossible(context: Context) {
        val token = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val data = hashMapOf(
            "token" to token,
            "platform" to "android",
            "updatedAt" to FieldValue.serverTimestamp()
        )
        db.collection("users").document(uid).collection("tokens").document(token)
            .set(data, SetOptions.merge())
    }
}
