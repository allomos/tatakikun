package com.tatakikun.android

import android.content.Context

/** How long a key is held for its long press, set in the app; kept across restarts. */
object KeySettings {
    const val DEFAULT_MS = 300
    const val MIN_MS = 200
    const val MAX_MS = 600
    /** The slider moves in steps of this many ms. */
    const val STEP_MS = 50

    private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    fun longPressMs(context: Context): Int = prefs(context).getInt("long_press_ms", DEFAULT_MS).coerceIn(MIN_MS, MAX_MS)

    fun setLongPressMs(context: Context, ms: Int) {
        prefs(context).edit().putInt("long_press_ms", ms.coerceIn(MIN_MS, MAX_MS)).apply()
    }
}
