package com.tatakikun.android

import android.content.Context

/** The input languages the user turned off in the app (by pack name: zh, ja, en, es, fr, hi, bn, ar); kept across restarts. */
object Languages {
    /** The packs in the app, in the order the settings show them, with their names. */
    val all = listOf("en" to "English", "zh" to "中文", "ja" to "日本語", "es" to "Español", "fr" to "Français", "hi" to "हिन्दी", "bn" to "বাংলা", "ar" to "العربية")

    private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    /** The languages on before the user has chosen any. */
    private val onAtFirst = setOf("zh", "ja", "en")

    /**
     * The languages turned off; before the user has chosen, every installed pack but zh, ja and en
     * (all on when none of those is installed, so at least one gives candidates).
     */
    fun turnedOff(context: Context): Set<String> {
        prefs(context).getStringSet("languages_off", null)?.let { return it }
        val installed = context.assets.list("packs").orEmpty().toSet()
        val off = installed - onAtFirst
        return if (off.size == installed.size) emptySet() else off
    }

    fun setTurnedOff(context: Context, languages: Set<String>) {
        prefs(context).edit().putStringSet("languages_off", languages.toSet()).apply()
    }
}
