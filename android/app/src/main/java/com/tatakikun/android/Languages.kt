package com.tatakikun.android

import android.content.Context

/** The input languages the user turned off in the app (by pack name: zh, ja, en, es, fr, hi, bn); kept across restarts. */
object Languages {
    /** The packs in the app, in the order the settings show them, with their names. */
    val all = listOf("en" to "English", "zh" to "中文", "ja" to "日本語", "es" to "Español", "fr" to "Français", "hi" to "हिन्दी", "bn" to "বাংলা")

    private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    fun turnedOff(context: Context): Set<String> = prefs(context).getStringSet("languages_off", null).orEmpty()

    fun setTurnedOff(context: Context, languages: Set<String>) {
        prefs(context).edit().putStringSet("languages_off", languages.toSet()).apply()
    }
}
