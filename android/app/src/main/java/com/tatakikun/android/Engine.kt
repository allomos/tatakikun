package com.tatakikun.android

import org.json.JSONObject

/** One candidate: its text, the tag of its kind (中, 日, あ, ア, EN, abc), and whether it matches all the letters. */
data class Candidate(val text: String, val kind: String, val exact: Boolean)

/** What the keyboard shows after a key, and what to insert. */
data class State(
    val handled: Boolean,
    val commit: String?,
    val input: String,
    val rows: List<List<Candidate>>,
    val selectedRow: Int,
    val selectedColumn: Int,
    val expanded: Boolean,
    val canExpand: Boolean,
) {
    val composing get() = input.isNotEmpty()

    companion object {
        fun parse(bytes: ByteArray?): State? {
            if (bytes == null) return null
            val o = JSONObject(String(bytes, Charsets.UTF_8))
            val rows = o.getJSONArray("rows").let { rs ->
                (0 until rs.length()).map { r ->
                    val row = rs.getJSONArray(r)
                    (0 until row.length()).map { i ->
                        val c = row.getJSONObject(i)
                        Candidate(c.getString("text"), c.getString("kind"), c.getBoolean("exact"))
                    }
                }
            }
            return State(
                handled = o.getBoolean("handled"),
                commit = if (o.isNull("commit")) null else o.getString("commit"),
                input = o.getString("input"),
                rows = rows,
                selectedRow = o.getInt("selectedRow"),
                selectedColumn = o.getInt("selectedColumn"),
                expanded = o.getBoolean("expanded"),
                canExpand = o.getBoolean("canExpand"),
            )
        }
    }
}

/** The Swift engine (libTatakikunEngine.so) through the JNI glue (libtatakikun_jni.so). */
class Engine(packs: String, data: String) {
    private val handle = create(packs, data)
    val isOpen get() = handle != 0L

    fun setTextBefore(text: CharSequence?) = setTextBefore(handle, text?.toString()?.toByteArray(Charsets.UTF_8))
    fun key(kind: Int, char: Int = 0) = State.parse(key(handle, kind, char))
    fun choose(row: Int, column: Int) = State.parse(choose(handle, row, column))
    fun finish() = State.parse(finish(handle))
    fun close() { if (handle != 0L) destroy(handle) }

    /** The composer's keys (Key in TatakikunCore). */
    object Keys {
        const val LETTER = 0; const val DIGIT = 1; const val BACKSPACE = 2; const val ESCAPE = 3
        const val SPACE = 4; const val ENTER = 5; const val LEFT = 6; const val RIGHT = 7
        const val UP = 8; const val DOWN = 9; const val TAB = 10; const val OTHER = 11
    }

    companion object {
        init { System.loadLibrary("tatakikun_jni") }
        @JvmStatic private external fun create(packs: String, data: String): Long
        @JvmStatic private external fun destroy(handle: Long)
        @JvmStatic private external fun setTextBefore(handle: Long, text: ByteArray?)
        @JvmStatic private external fun key(handle: Long, kind: Int, scalar: Int): ByteArray?
        @JvmStatic private external fun choose(handle: Long, row: Int, column: Int): ByteArray?
        @JvmStatic private external fun finish(handle: Long): ByteArray?
    }
}
