package com.tatakikun.android

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * The Tatakikun keyboard, laid out like the Pixel's own keyboard (Gboard): a toolbar that turns into
 * the candidate bar while typing, a number row, letters with a symbol on long press, and a layer of
 * symbols behind ?123. Above it, over the application, a small box shows the letters being typed;
 * only the panel below it takes touches ([panelTop]). ⌄ shows more candidates in place of the keys.
 */
@SuppressLint("ViewConstructor")
class KeyboardView(context: Context, private val listener: Listener) : LinearLayout(context) {
    interface Listener {
        fun onKey(kind: Int, char: Int = 0)
        fun onChoose(row: Int, column: Int)
        fun onAction(action: Action)
    }

    enum class Action { SETTINGS, PASTE, LEFT, RIGHT }

    private val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    private val panelColor = if (dark) Color.rgb(0x1f, 0x20, 0x24) else Color.rgb(0xe8, 0xed, 0xf3)
    private val textColor = if (dark) Color.rgb(0xe3, 0xe3, 0xe8) else Color.rgb(0x1b, 0x1d, 0x21)
    private val hintColor = if (dark) Color.rgb(0x9a, 0x9e, 0xa6) else Color.rgb(0x6f, 0x74, 0x7c)
    private val grayText = if (dark) Color.rgb(0x8e, 0x92, 0x9a) else Color.rgb(0x80, 0x85, 0x8d)
    private val keyColor = if (dark) Color.rgb(0x3a, 0x3c, 0x41) else Color.WHITE
    private val functionColor = if (dark) Color.rgb(0x3e, 0x48, 0x5a) else Color.rgb(0xd3, 0xe3, 0xfd)
    private val functionText = if (dark) Color.rgb(0xd3, 0xe3, 0xfd) else Color.rgb(0x0b, 0x2a, 0x5c)
    private val pressedColor = if (dark) Color.argb(0x40, 0xff, 0xff, 0xff) else Color.argb(0x30, 0x00, 0x00, 0x00)
    private val dividerColor = if (dark) Color.rgb(0x4a, 0x4d, 0x53) else Color.rgb(0xb9, 0xbe, 0xc6)

    private val reading = TextView(context)
    private val panel = LinearLayout(context)
    private val toolbar = LinearLayout(context)
    private val candidates = LinearLayout(context)
    private val barRow = LinearLayout(context)
    private val barScroll = HorizontalScrollView(context)
    private val toggle = ImageView(context)
    private val keys = LinearLayout(context)
    private val moreScroll = ScrollView(context)
    private val more = LinearLayout(context)
    private var symbols = false
    private var shift = false
    private var expanded = false

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    /** Where the keyboard's panel starts, below the box with the letters: the part that takes touches. */
    val panelTop get() = panel.top

    init {
        orientation = VERTICAL
        // The box with the letters being typed sits over the application, in an otherwise empty strip.
        val strip = FrameLayout(context)
        reading.apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f); setTextColor(textColor)
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), 0, dp(12), 0)
            background = GradientDrawable().apply { setColor(keyColor); setStroke(dp(1), dividerColor) }
            visibility = INVISIBLE
        }
        strip.addView(reading, FrameLayout.LayoutParams(LayoutParams.WRAP_CONTENT, dp(32), Gravity.BOTTOM or Gravity.START))
        addView(strip, LayoutParams(LayoutParams.MATCH_PARENT, dp(32)))

        panel.orientation = VERTICAL
        panel.setBackgroundColor(panelColor)
        // Below Android 15 the keyboard ends above the navigation bar; from 15 on it reaches under
        // it, and the bar's ⌄ and keyboard switch would cover the bottom row: keep that space free.
        panel.setOnApplyWindowInsetsListener { v, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= 30) insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                else @Suppress("DEPRECATION") insets.systemWindowInsetBottom
            v.setPadding(0, 0, 0, bottom)
            insets
        }
        addView(panel, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        val bar = FrameLayout(context)
        toolbar.apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; setPadding(dp(6), 0, dp(6), 0) }
        toolbar.addView(icon(R.drawable.ic_settings, "settings") { listener.onAction(Action.SETTINGS) }, LayoutParams(dp(48), dp(44)))
        toolbar.addView(View(context), LayoutParams(0, 1, 1f))
        toolbar.addView(icon(R.drawable.ic_paste, "paste") { listener.onAction(Action.PASTE) }, LayoutParams(dp(48), dp(44)))
        toolbar.addView(View(context), LayoutParams(0, 1, 1f))
        toolbar.addView(icon(R.drawable.ic_left, "cursorLeft") { listener.onAction(Action.LEFT) }, LayoutParams(dp(44), dp(44)))
        toolbar.addView(icon(R.drawable.ic_right, "cursorRight") { listener.onAction(Action.RIGHT) }, LayoutParams(dp(44), dp(44)))
        bar.addView(toolbar, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(50)))

        candidates.apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        barScroll.isHorizontalScrollBarEnabled = false
        barRow.orientation = HORIZONTAL
        barRow.gravity = Gravity.CENTER_VERTICAL
        barScroll.addView(barRow)
        candidates.addView(barScroll, LayoutParams(0, dp(50), 1f))
        toggle.apply {
            scaleType = ImageView.ScaleType.CENTER
            setColorFilter(textColor)
            contentDescription = "expand"
            setOnClickListener { listener.onKey(if (expanded) Engine.Keys.ESCAPE else Engine.Keys.DOWN) }
        }
        candidates.addView(toggle, LayoutParams(dp(44), dp(50)))
        bar.addView(candidates, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(50)))
        panel.addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, dp(50)))

        val body = FrameLayout(context)
        keys.orientation = VERTICAL
        keys.setPadding(dp(3), 0, dp(3), dp(4))
        body.addView(keys, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(5 * ROW + 4)))
        more.orientation = VERTICAL
        moreScroll.addView(more)
        moreScroll.visibility = GONE
        body.addView(moreScroll, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(5 * ROW + 4)))
        panel.addView(body, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        buildKeys()
        show(null)
    }

    /** Shows the candidates of `state` (the toolbar when not composing). */
    fun show(state: State?) {
        val composing = state?.composing == true
        reading.text = state?.input.orEmpty()
        reading.visibility = if (composing) VISIBLE else INVISIBLE
        toolbar.visibility = if (composing) GONE else VISIBLE
        candidates.visibility = if (composing) VISIBLE else GONE

        barRow.removeAllViews()
        // The first candidate is what Space picks; a highlight only once the arrows move away from it.
        val moved = state != null && (state.selectedRow != 0 || state.selectedColumn != 0)
        state?.rows?.firstOrNull().orEmpty().forEachIndexed { i, c ->
            if (i > 0) barRow.addView(divider(), LayoutParams(dp(1), dp(24)))
            barRow.addView(candidateView(c, 22f, moved && state?.selectedRow == 0 && state.selectedColumn == i) { listener.onChoose(0, i) },
                LayoutParams(LayoutParams.WRAP_CONTENT, dp(44)))
        }
        barScroll.scrollTo(0, 0)
        expanded = state?.expanded == true
        toggle.setImageResource(if (expanded) R.drawable.ic_collapse else R.drawable.ic_expand)
        toggle.visibility = if (state?.canExpand == true || expanded) VISIBLE else INVISIBLE
        keys.visibility = if (expanded) GONE else VISIBLE
        moreScroll.visibility = if (expanded) VISIBLE else GONE
        more.removeAllViews()
        if (expanded && state != null) {
            state.rows.drop(1).forEachIndexed { r, row ->
                val line = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
                row.forEachIndexed { c, cand ->
                    if (c > 0) line.addView(divider(), LayoutParams(dp(1), dp(20)))
                    line.addView(candidateView(cand, 20f, state.selectedRow == r + 1 && state.selectedColumn == c) { listener.onChoose(r + 1, c) },
                        LayoutParams(LayoutParams.WRAP_CONTENT, dp(44)))
                }
                val strip = HorizontalScrollView(context).apply { isHorizontalScrollBarEnabled = false; addView(line) }
                more.addView(strip, LayoutParams(LayoutParams.MATCH_PARENT, dp(46)))
            }
            moreScroll.scrollTo(0, 0)
        }
    }

    private fun divider() = View(context).apply { setBackgroundColor(dividerColor) }

    private fun candidateView(c: Candidate, size: Float, selected: Boolean, onClick: () -> Unit) = TextView(context).apply {
        text = c.text
        contentDescription = c.text
        gravity = Gravity.CENTER
        minWidth = dp(56)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        // Gray: matches only part of the letters (a completion, a correction, the start of them).
        setTextColor(if (c.exact) textColor else grayText)
        setPadding(dp(12), 0, dp(12), 0)
        background = pressable(if (selected) functionColor else Color.TRANSPARENT, dp(22).toFloat())
        setOnClickListener { onClick() }
    }

    private fun icon(res: Int, id: String, onClick: () -> Unit) = ImageView(context).apply {
        setImageResource(res)
        setColorFilter(textColor)
        scaleType = ImageView.ScaleType.CENTER
        contentDescription = id
        background = pressable(Color.TRANSPARENT, dp(22).toFloat())
        setOnClickListener { onClick() }
    }

    private fun buildKeys() {
        keys.removeAllViews()
        keys.addView(weighted("1234567890".map { ch -> key(ch.toString(), ch.toString()) { listener.onKey(Engine.Keys.DIGIT, ch.code) } to 1f }), rowParams())

        val letters = listOf("qwertyuiop", "asdfghjkl", "zxcvbnm")
        val symbolRows = listOf("@#$%&-+()/", "*\"':;!?=_", "[]{}<>\\|")
        (if (symbols) symbolRows else letters).forEachIndexed { i, chars ->
            val views = mutableListOf<Pair<View, Float>>()
            if (i == 1 && !symbols) views += View(context) to 0.5f
            if (i == 2) views += (if (symbols) View(context) else shiftKey()) to 1.5f
            for (ch in chars) {
                val shown = if (shift && !symbols) ch.uppercase() else ch.toString()
                val hint = if (symbols) null else HINTS[ch]
                views += key(shown, shown, hint = hint, onLongPress = hint?.let { h -> { listener.onKey(Engine.Keys.OTHER, h.code) } }) {
                    val c = shown[0]
                    if (c.isLetter()) {
                        listener.onKey(Engine.Keys.LETTER, c.code)
                        if (shift) { shift = false; buildKeys() }
                    } else listener.onKey(Engine.Keys.OTHER, c.code)
                } to 1f
            }
            if (i == 1 && !symbols) views += View(context) to 0.5f
            if (i == 2) views += deleteKey() to 1.5f
            keys.addView(weighted(views), rowParams())
        }

        keys.addView(weighted(listOf(
            key(if (symbols) "ABC" else "?123", "layer", Style.PILL) { symbols = !symbols; shift = false; buildKeys() } to 1.5f,
            // The composer types ， or , (。 or .) to suit the text around it.
            key("，", "comma", Style.PILL, hint = '、', onLongPress = { listener.onKey(Engine.Keys.OTHER, '、'.code) }) {
                listener.onKey(Engine.Keys.OTHER, ','.code)
            } to 1f,
            key("Tatakikun", "space", textSize = 14f, ink = grayText) { listener.onKey(Engine.Keys.SPACE) } to 4.6f,
            key("。", "period", Style.PILL, hint = '?', onLongPress = { listener.onKey(Engine.Keys.OTHER, '?'.code) }) {
                listener.onKey(Engine.Keys.OTHER, '.'.code)
            } to 1f,
            key("", "return", Style.PILL, iconRes = R.drawable.ic_return) { listener.onKey(Engine.Keys.ENTER) } to 1.5f,
        )), rowParams())
    }

    private fun shiftKey() = key("", "shift", Style.FUNCTION, iconRes = if (shift) R.drawable.ic_shift_on else R.drawable.ic_shift) {
        shift = !shift; buildKeys()
    }

    /** Delete: held down, it deletes again and again, like Gboard. */
    @SuppressLint("ClickableViewAccessibility")
    private fun deleteKey(): View {
        val repeat = object : Runnable {
            override fun run() { listener.onKey(Engine.Keys.BACKSPACE); postDelayed(this, 60) }
        }
        val view = key("", "delete", Style.FUNCTION, iconRes = R.drawable.ic_backspace) { listener.onKey(Engine.Keys.BACKSPACE) }
        val face = (view as FrameLayout).getChildAt(0)
        face.setOnLongClickListener { post(repeat); true }
        face.setOnTouchListener { _, e ->
            if (e.action == MotionEvent.ACTION_UP || e.action == MotionEvent.ACTION_CANCEL) removeCallbacks(repeat)
            false
        }
        return view
    }

    private fun weighted(views: List<Pair<View, Float>>) = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        for ((v, w) in views) addView(v, LayoutParams(0, LayoutParams.MATCH_PARENT, w))
    }

    private fun rowParams() = LayoutParams(LayoutParams.MATCH_PARENT, dp(ROW))

    private enum class Style { LETTER, FUNCTION, PILL }

    private fun pressable(color: Int, radius: Float): RippleDrawable {
        val shape = GradientDrawable().apply { cornerRadius = radius; setColor(color) }
        val mask = GradientDrawable().apply { cornerRadius = radius; setColor(Color.WHITE) }
        return RippleDrawable(ColorStateList.valueOf(pressedColor), shape, mask)
    }

    /**
     * A key: its face with rounded corners (letters and shift / delete) or a pill (the bottom row's
     * function keys), inside a frame that makes the gap to the next key; a symbol in the corner
     * types on a long press.
     */
    private fun key(
        label: String, id: String, style: Style = Style.LETTER, hint: Char? = null, onLongPress: (() -> Unit)? = null,
        iconRes: Int = 0, textSize: Float = 0f, ink: Int = 0, onClick: () -> Unit,
    ): View {
        val function = style != Style.LETTER
        val color = if (ink != 0) ink else if (function) functionText else textColor
        val face = FrameLayout(context).apply {
            contentDescription = id
            background = pressable(if (function) functionColor else keyColor, dp(if (style == Style.PILL) 21 else 8).toFloat())
            setOnClickListener { onClick() }
            if (onLongPress != null) setOnLongClickListener { onLongPress(); true }
        }
        if (iconRes != 0) {
            face.addView(ImageView(context).apply { setImageResource(iconRes); setColorFilter(color); scaleType = ImageView.ScaleType.CENTER },
                FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        } else {
            face.addView(TextView(context).apply {
                text = label
                gravity = Gravity.CENTER
                setTextColor(color)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, if (textSize > 0) textSize else if (label.length == 1) 21f else 15f)
            }, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
        if (hint != null) {
            face.addView(TextView(context).apply {
                text = hint.toString()
                setTextColor(if (function) functionText else hintColor)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                setPadding(0, dp(1), dp(4), 0)
            }, FrameLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END))
        }
        return FrameLayout(context).apply {
            setPadding(dp(3), dp(4), dp(3), dp(4))
            addView(face, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
    }

    companion object {
        /** The height of a row of keys, in dp. */
        const val ROW = 50

        /** The symbol a long press on each letter types, as on Gboard. */
        val HINTS = mapOf(
            'q' to '%', 'w' to '\\', 'e' to '|', 'r' to '=', 't' to '[', 'y' to ']', 'u' to '<', 'i' to '>', 'o' to '{', 'p' to '}',
            'a' to '@', 's' to '#', 'd' to '$', 'f' to '-', 'g' to '&', 'h' to '_', 'j' to '+', 'k' to '(', 'l' to ')',
            'z' to '*', 'x' to '"', 'c' to '\'', 'v' to ':', 'b' to ';', 'n' to '!', 'm' to '?',
        )
    }
}
