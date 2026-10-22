package com.tatakikun.android

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * The Tatakikun keyboard: a candidate bar over a QWERTY layout (a layer of digits and punctuation
 * behind 123), like the iOS keyboard. ⌄ shows more candidates in place of the keys.
 */
@SuppressLint("ViewConstructor")
class KeyboardView(context: Context, private val listener: Listener) : LinearLayout(context) {
    interface Listener {
        fun onKey(kind: Int, char: Int = 0)
        fun onChoose(row: Int, column: Int)
        fun onNextKeyboard()
    }

    private val dark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
        android.content.res.Configuration.UI_MODE_NIGHT_YES
    private val textColor = if (dark) Color.WHITE else Color.BLACK
    private val grayText = Color.GRAY
    private val keyColor = if (dark) Color.rgb(0x6b, 0x6b, 0x6b) else Color.WHITE
    private val darkKeyColor = if (dark) Color.rgb(0x46, 0x46, 0x46) else Color.rgb(0xad, 0xb3, 0xbc)
    private val selectedColor = Color.argb(0x40, 0x1e, 0x88, 0xe5)

    private val barRow = LinearLayout(context)
    private val barScroll = HorizontalScrollView(context)
    private val toggle = TextView(context)
    private val keys = LinearLayout(context)
    private val moreScroll = ScrollView(context)
    private val more = LinearLayout(context)
    private var symbols = false
    private var shift = false
    var showsNextKeyboard = true
        set(value) { if (field != value) { field = value; buildKeys() } }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    init {
        orientation = VERTICAL
        setBackgroundColor(if (dark) Color.rgb(0x2b, 0x2b, 0x2b) else Color.rgb(0xd1, 0xd4, 0xd9))
        val bar = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        barScroll.isHorizontalScrollBarEnabled = false
        barRow.orientation = HORIZONTAL
        barScroll.addView(barRow)
        bar.addView(barScroll, LayoutParams(0, dp(48), 1f))
        toggle.apply {
            gravity = Gravity.CENTER; setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f); setTextColor(textColor)
            contentDescription = "expand"
            setOnClickListener { listener.onKey(if (expanded) Engine.Keys.ESCAPE else Engine.Keys.DOWN) }
        }
        bar.addView(toggle, LayoutParams(dp(48), dp(48)))
        addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, dp(48)))

        val body = FrameLayout(context)
        keys.orientation = VERTICAL
        keys.setPadding(dp(3), dp(4), dp(3), dp(4))
        body.addView(keys, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(4 * 54 + 8)))
        more.orientation = VERTICAL
        moreScroll.addView(more)
        moreScroll.visibility = GONE
        body.addView(moreScroll, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(4 * 54 + 8)))
        addView(body, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        buildKeys()
        show(null)
    }

    private var expanded = false

    /** Shows the candidates of `state` (none when not composing). */
    fun show(state: State?) {
        barRow.removeAllViews()
        val first = state?.rows?.firstOrNull().orEmpty()
        first.forEachIndexed { i, c ->
            barRow.addView(candidateView(c, state?.selectedRow == 0 && state.selectedColumn == i) { listener.onChoose(0, i) },
                LayoutParams(LayoutParams.WRAP_CONTENT, dp(48)))
        }
        barScroll.scrollTo(0, 0)
        expanded = state?.expanded == true
        toggle.text = if (expanded) "⌃" else "⌄"
        toggle.visibility = if (state?.canExpand == true || expanded) VISIBLE else INVISIBLE
        keys.visibility = if (expanded) GONE else VISIBLE
        moreScroll.visibility = if (expanded) VISIBLE else GONE
        more.removeAllViews()
        if (expanded && state != null) {
            state.rows.drop(1).forEachIndexed { r, row ->
                val line = LinearLayout(context).apply { orientation = HORIZONTAL }
                row.forEachIndexed { c, cand ->
                    line.addView(candidateView(cand, false) { listener.onChoose(r + 1, c) }, LayoutParams(LayoutParams.WRAP_CONTENT, dp(44)))
                }
                val strip = HorizontalScrollView(context).apply { isHorizontalScrollBarEnabled = false; addView(line) }
                more.addView(strip, LayoutParams(LayoutParams.MATCH_PARENT, dp(44)))
            }
            moreScroll.scrollTo(0, 0)
        }
    }

    private fun candidateView(c: Candidate, selected: Boolean, onClick: () -> Unit) = TextView(context).apply {
        text = c.text
        contentDescription = c.text
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
        // Gray: matches only part of the letters (a completion, a correction, the start of them).
        setTextColor(if (c.exact) textColor else grayText)
        setPadding(dp(10), 0, dp(10), 0)
        background = GradientDrawable().apply { cornerRadius = dp(6).toFloat(); setColor(if (selected) selectedColor else Color.TRANSPARENT) }
        setOnClickListener { onClick() }
    }

    private fun buildKeys() {
        keys.removeAllViews()
        val top = if (symbols) listOf("1234567890", "-/:;()&@\"", ".,?!'") else listOf("qwertyuiop", "asdfghjkl", "zxcvbnm")
        top.forEachIndexed { i, chars ->
            val row = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER }
            if (i == 2) row.addView(if (symbols) spacer() else key(if (shift) "⇧" else "⇧", "shift", !shift) { shift = !shift; buildKeys() }, weight(1.4f))
            if (i == 1 && !symbols) row.addView(spacer(), weight(0.5f))
            for (ch in chars) {
                val shown = if (shift && !symbols) ch.uppercase() else ch.toString()
                row.addView(key(shown, shown) {
                    val c = shown[0]
                    when {
                        c.isLetter() -> { listener.onKey(Engine.Keys.LETTER, c.code); if (shift) { shift = false; buildKeys() } }
                        c.isDigit() -> listener.onKey(Engine.Keys.DIGIT, c.code)
                        else -> listener.onKey(Engine.Keys.OTHER, c.code)
                    }
                }, weight(1f))
            }
            if (i == 1 && !symbols) row.addView(spacer(), weight(0.5f))
            if (i == 2) row.addView(key("⌫", "delete", true) { listener.onKey(Engine.Keys.BACKSPACE) }, weight(1.4f))
            keys.addView(row, LayoutParams(LayoutParams.MATCH_PARENT, dp(54)))
        }
        val bottom = LinearLayout(context).apply { orientation = HORIZONTAL }
        bottom.addView(key(if (symbols) "ABC" else "123", "layer", true) { symbols = !symbols; buildKeys() }, weight(1.3f))
        if (showsNextKeyboard) bottom.addView(key("🌐", "nextKeyboard", true) { listener.onNextKeyboard() }, weight(1.1f))
        bottom.addView(key("，", "comma", true) { listener.onKey(Engine.Keys.OTHER, ','.code) }, weight(1f))
        bottom.addView(key("space", "space", false) { listener.onKey(Engine.Keys.SPACE) }, weight(4f))
        bottom.addView(key("。", "period", true) { listener.onKey(Engine.Keys.OTHER, '.'.code) }, weight(1f))
        bottom.addView(key("return", "return", true) { listener.onKey(Engine.Keys.ENTER) }, weight(2f))
        keys.addView(bottom, LayoutParams(LayoutParams.MATCH_PARENT, dp(54)))
    }

    private fun weight(w: Float) = LayoutParams(0, LayoutParams.MATCH_PARENT, w)
    private fun spacer() = View(context)

    /** A key: its face with rounded corners, inside a frame that makes the gap to the next key. */
    private fun key(label: String, id: String, darkKey: Boolean = false, onClick: () -> Unit): View {
        val face = TextView(context).apply {
            text = label
            contentDescription = id
            gravity = Gravity.CENTER
            setTextColor(textColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (label.length == 1) 22f else 16f)
            background = GradientDrawable().apply { cornerRadius = dp(5).toFloat(); setColor(if (darkKey) darkKeyColor else keyColor) }
            setOnClickListener { onClick() }
        }
        return FrameLayout(context).apply {
            setPadding(dp(3), dp(4), dp(3), dp(4))
            addView(face, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
    }
}
