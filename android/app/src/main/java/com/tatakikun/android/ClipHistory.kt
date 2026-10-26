package com.tatakikun.android

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * The text copied lately, newest first, for the keyboard's clipboard list; the latest copy is also
 * offered as a chip for a while, until it is pasted from there. Kept only on the phone ([store]).
 * The same rules as the iOS keyboard's ClipboardHistory.
 */
class ClipHistory(private val store: Store) {
    /** Where the history is kept between keyboard runs. */
    interface Store {
        fun load(): Saved?
        fun save(saved: Saved)
    }

    data class Saved(val items: List<String>, val chip: String?, val chipSince: Long)

    private val list = mutableListOf<String>()
    private var chipText: String? = null
    private var chipSince = 0L

    val items: List<String> get() = list

    init {
        store.load()?.let { list += it.items; chipText = it.chip; chipSince = it.chipSince }
    }

    /** Records a copy: it goes on top (moved up when it is there already) and becomes the chip. Blank or very long text is left out. */
    fun add(text: String, now: Long = System.currentTimeMillis()) {
        if (text.isBlank() || text.length > LONGEST) return
        list.remove(text)
        list.add(0, text)
        while (list.size > LIMIT) list.removeAt(list.size - 1)
        chipText = text
        chipSince = now
        save()
    }

    /** The latest copy while it is offered as a chip. */
    fun chip(now: Long = System.currentTimeMillis()): String? =
        chipText?.takeIf { now - chipSince < CHIP_MS && list.firstOrNull() == it }

    /** The chip was used: it goes away (the copy stays in the list). */
    fun dismissChip() {
        chipText = null
        save()
    }

    fun remove(index: Int) {
        if (index !in list.indices) return
        list.removeAt(index)
        save()
    }

    fun clear() {
        list.clear()
        chipText = null
        save()
    }

    private fun save() = store.save(Saved(list.toList(), chipText, chipSince))

    /** Kept in the app's private settings, as JSON. */
    class Prefs(context: Context) : Store {
        private val prefs = context.getSharedPreferences("clipboard", Context.MODE_PRIVATE)

        override fun load(): Saved? {
            val json = prefs.getString("history", null) ?: return null
            return runCatching {
                val o = JSONObject(json)
                val items = o.getJSONArray("items").let { a -> List(a.length()) { a.getString(it) } }
                Saved(items, if (o.isNull("chip")) null else o.getString("chip"), o.optLong("chipSince"))
            }.getOrNull()
        }

        override fun save(saved: Saved) {
            val o = JSONObject().put("items", JSONArray(saved.items)).put("chip", saved.chip ?: JSONObject.NULL).put("chipSince", saved.chipSince)
            prefs.edit().putString("history", o.toString()).apply()
        }
    }

    companion object {
        /** How many copies the list keeps: the oldest drop off. */
        const val LIMIT = 30
        /** Longer copies are left out: the list is for snippets, not whole documents. */
        const val LONGEST = 20_000
        /** How long the latest copy is offered as a chip, in ms. */
        const val CHIP_MS = 10 * 60 * 1000L
    }
}
