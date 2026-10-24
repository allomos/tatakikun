package com.tatakikun.android

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.SystemClock
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
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
 * A key that types a character shows it in a popup above the finger ([KeyPopup]); held, the popup
 * offers its symbol half-width and full-width.
 */
@SuppressLint("ViewConstructor")
class KeyboardView(context: Context, private val listener: Listener) : LinearLayout(context) {
    interface Listener {
        fun onKey(kind: Int, char: Int = 0)
        fun onChoose(row: Int, column: Int)
        /** A symbol chosen in the long-press popup, typed exactly as shown. */
        fun onSymbol(text: String)
        fun onAction(action: Action)
    }

    enum class Action { SETTINGS, PASTE, LEFT, RIGHT, SELECT_ALL, COPY, CUT, UNDO, REDO }

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
    private val shadowColor = if (dark) Color.argb(0x8c, 0, 0, 0) else Color.argb(0x2e, 0, 0, 0)
    private val edgeColor = if (dark) Color.argb(0x12, 0xff, 0xff, 0xff) else Color.argb(0x0d, 0, 0, 0)

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
    /** Shift: off, on for the next letter only, or caps lock (two quick taps) until tapped again. */
    private enum class Shift { OFF, ONCE, LOCKED }
    private var shift = Shift.OFF
    private var lastShiftTap = 0L
    /** A tablet (the smallest screen side 600 dp or more) has a Ctrl key; held, it turns a, c, v, y, z into shortcuts. */
    private val tablet = resources.configuration.smallestScreenWidthDp >= 600
    private var ctrl = false
    private val shortcutFaces = mutableListOf<View>()
    /** Every key's face, for handing a finger to the nearest one ([KeyArea]). */
    private val faces = mutableListOf<View>()
    private var expanded = false
    /** ⌄ opened here, to show the bar's candidates that did not fit when the engine has no more rows. */
    private var overflowOpen = false
    private var last: State? = null
    private val popup = KeyPopup()
    private val slop = ViewConfiguration.get(context).scaledTouchSlop

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
    private fun sp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    /**
     * The height of a row of keys, in dp: lower on a short landscape screen, so the application
     * keeps room above the keyboard.
     */
    private val row = if (resources.configuration.screenHeightDp < 480) ROW_LOW else ROW

    /**
     * The keys' width at most, in pixels: on a wide screen (a phone sideways, a tablet) the keys
     * stay in a block of a comfortable size in the middle instead of stretching across it.
     */
    private val keysWidth = resources.configuration.screenWidthDp.let { if (it > MAX_WIDTH) dp(MAX_WIDTH) else LayoutParams.MATCH_PARENT }

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
        // The keyboard draws that bar itself and Android reports it as a caption bar, not a
        // navigation bar, so ask for all system bars.
        panel.setOnApplyWindowInsetsListener { v, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= 30) insets.getInsets(WindowInsets.Type.systemBars()).bottom
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
            setOnClickListener {
                when {
                    expanded -> listener.onKey(Engine.Keys.ESCAPE)
                    overflowOpen || last?.canExpand != true -> { overflowOpen = !overflowOpen; show(last) }
                    else -> listener.onKey(Engine.Keys.DOWN)
                }
            }
        }
        candidates.addView(toggle, LayoutParams(dp(44), dp(50)))
        bar.addView(candidates, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(50)))
        panel.addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, dp(50)))

        val body = KeyArea()
        keys.orientation = VERTICAL
        keys.setPadding(dp(3), 0, dp(3), dp(4))
        body.addView(keys, FrameLayout.LayoutParams(keysWidth, dp(5 * row + 4), Gravity.CENTER_HORIZONTAL))
        more.orientation = VERTICAL
        moreScroll.addView(more)
        moreScroll.visibility = GONE
        body.addView(moreScroll, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, dp(5 * row + 4)))
        panel.addView(body, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        overlay.add(popup)
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

        if (state?.composing != true || state.input != last?.input) overflowOpen = false
        last = state

        // The bar holds the candidates that fit whole (the first one always, cut short if it must);
        // the others of its row lead the list under ⌄.
        val screen = if (width > 0) width else resources.displayMetrics.widthPixels
        val room = screen - dp(44)
        barRow.removeAllViews()
        // The first candidate is what Space picks; a highlight only once the arrows move away from it.
        val moved = state != null && (state.selectedRow != 0 || state.selectedColumn != 0)
        val first = state?.rows?.firstOrNull().orEmpty()
        var used = 0
        var fitting = 0
        for ((i, c) in first.withIndex()) {
            val view = candidateView(c, 22f, moved && state?.selectedRow == 0 && state.selectedColumn == i) { listener.onChoose(0, i) }
            val w = measuredWidth(view) + if (i > 0) dp(1) else 0
            if (i > 0 && used + w > room) break
            if (i == 0) view.apply { maxWidth = room; isSingleLine = true; ellipsize = TextUtils.TruncateAt.END }
            if (i > 0) barRow.addView(divider(), LayoutParams(dp(1), dp(24)))
            barRow.addView(view, LayoutParams(LayoutParams.WRAP_CONTENT, dp(44)))
            used += w
            fitting++
        }
        barScroll.scrollTo(0, 0)
        // Each candidate under ⌄ with where it is in the engine's rows, for choosing it.
        val hidden = first.drop(fitting).mapIndexed { j, c -> Triple(0, fitting + j, c) }
        expanded = state?.expanded == true
        val open = expanded || overflowOpen
        toggle.setImageResource(if (open) R.drawable.ic_collapse else R.drawable.ic_expand)
        toggle.visibility = if (state?.canExpand == true || open || hidden.isNotEmpty()) VISIBLE else INVISIBLE
        keys.visibility = if (open) GONE else VISIBLE
        moreScroll.visibility = if (open) VISIBLE else GONE
        more.removeAllViews()
        if (open && state != null) {
            val rest = if (expanded) state.rows.drop(1).flatMapIndexed { r, row -> row.mapIndexed { c, cand -> Triple(r + 1, c, cand) } } else emptyList()
            // Lines as wide as the screen, filled in order: nothing runs past the edge.
            var line: LinearLayout? = null
            var lineWidth = 0
            for ((r, c, cand) in hidden + rest) {
                val view = candidateView(cand, 20f, expanded && state.selectedRow == r && state.selectedColumn == c) { listener.onChoose(r, c) }
                view.apply { maxWidth = screen; isSingleLine = true; ellipsize = TextUtils.TruncateAt.END }
                val w = minOf(measuredWidth(view), screen)
                if (line == null || lineWidth + dp(1) + w > screen) {
                    line = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
                    more.addView(line, LayoutParams(LayoutParams.MATCH_PARENT, dp(46)))
                    lineWidth = 0
                } else {
                    line.addView(divider(), LayoutParams(dp(1), dp(20)))
                    lineWidth += dp(1)
                }
                line.addView(view, LayoutParams(LayoutParams.WRAP_CONTENT, dp(44)))
                lineWidth += w
            }
            moreScroll.scrollTo(0, 0)
        }
    }

    private fun measuredWidth(v: View): Int {
        v.measure(MeasureSpec.UNSPECIFIED, MeasureSpec.UNSPECIFIED)
        return v.measuredWidth
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
        shortcutFaces.clear()
        faces.clear()
        keys.addView(weighted("1234567890".map { ch -> key(ch.toString(), ch.toString(), preview = true) { listener.onKey(Engine.Keys.DIGIT, ch.code) } to 1f }), rowParams())

        val letters = listOf("qwertyuiop", "asdfghjkl", "zxcvbnm")
        val symbolRows = listOf("@#$%&-+()/", "*\"':;!?=_", "[]{}<>\\|")
        (if (symbols) symbolRows else letters).forEachIndexed { i, chars ->
            val views = mutableListOf<Pair<View, Float>>()
            if (i == 1 && !symbols) views += View(context) to 0.5f
            if (i == 2) views += (if (symbols) View(context) else shiftKey()) to 1.5f
            for (ch in chars) {
                val shown = if (shift != Shift.OFF && !symbols) ch.uppercase() else ch.toString()
                val hint = if (symbols) null else HINTS[ch]
                val letter = key(shown, shown, hint = hint, preview = true, onLongPress = hint?.let { h -> { listener.onKey(Engine.Keys.OTHER, h.code) } }) {
                    val c = shown[0]
                    if (ctrl) SHORTCUTS[ch]?.let { listener.onAction(it) }
                    else if (c.isLetter()) {
                        listener.onKey(Engine.Keys.LETTER, c.code)
                        if (shift == Shift.ONCE) { shift = Shift.OFF; buildKeys() }
                    } else listener.onKey(Engine.Keys.OTHER, c.code)
                }
                if (!symbols && ch in SHORTCUTS) shortcutFaces += (letter as ViewGroup).getChildAt(0)
                views += letter to 1f
            }
            if (i == 1 && !symbols) views += View(context) to 0.5f
            if (i == 2) views += deleteKey() to 1.5f
            keys.addView(weighted(views), rowParams())
        }

        keys.addView(weighted(listOfNotNull(
            if (tablet) ctrlKey() to 1.5f else null,
            key(if (symbols) "ABC" else "?123", "layer", Style.PILL) { symbols = !symbols; shift = Shift.OFF; buildKeys() } to 1.5f,
            // The composer types ， or , (。 or .) to suit the text around it.
            key("，", "comma", Style.PILL, hint = '、', preview = true, onLongPress = { listener.onKey(Engine.Keys.OTHER, '、'.code) }) {
                listener.onKey(Engine.Keys.OTHER, ','.code)
            } to 1f,
            key("Tatakikun", "space", textSize = 14f, ink = grayText) { listener.onKey(Engine.Keys.SPACE) } to if (tablet) 3.1f else 4.6f,
            key("。", "period", Style.PILL, hint = '?', preview = true, onLongPress = { listener.onKey(Engine.Keys.OTHER, '?'.code) }) {
                listener.onKey(Engine.Keys.OTHER, '.'.code)
            } to 1f,
            key("", "return", Style.PILL, iconRes = R.drawable.ic_return) { listener.onKey(Engine.Keys.ENTER) } to 1.5f,
        )), rowParams())
    }

    private fun shiftKey() = key("", "shift", Style.FUNCTION, iconRes = when (shift) {
        Shift.OFF -> R.drawable.ic_shift
        Shift.ONCE -> R.drawable.ic_shift_on
        Shift.LOCKED -> R.drawable.ic_shift_lock
    }) {
        val now = SystemClock.uptimeMillis()
        shift = when {
            shift == Shift.ONCE && now - lastShiftTap < DOUBLE_TAP_MS -> Shift.LOCKED
            shift == Shift.OFF -> Shift.ONCE
            else -> Shift.OFF
        }
        lastShiftTap = now
        buildKeys()
    }

    /**
     * Ctrl: while it is held down, a, c, v, y and z are highlighted and run select all, copy, cut,
     * redo and undo instead of typing. A tap alone does nothing.
     */
    private fun ctrlKey() = key("Ctrl", "ctrl", Style.PILL, onPress = { showCtrl(true) }, onRelease = { showCtrl(false) }) {}

    private fun showCtrl(on: Boolean) {
        if (ctrl == on) return
        ctrl = on
        val radius = dp(8).toFloat()
        for (face in shortcutFaces) face.background = pressable(if (on) functionColor else keyColor, radius)
    }

    /** Delete: held down, it deletes again and again, like Gboard. */
    private fun deleteKey(): View {
        val repeat = object : Runnable {
            override fun run() { listener.onKey(Engine.Keys.BACKSPACE); postDelayed(this, 60) }
        }
        return key("", "delete", Style.FUNCTION, iconRes = R.drawable.ic_backspace,
            onLongPress = { post(repeat) }, onRelease = { removeCallbacks(repeat) }) { listener.onKey(Engine.Keys.BACKSPACE) }
    }

    /**
     * Moves a corner symbol in along the diagonal until its glyph is inside the key's rounded shape:
     * on a narrow pill key (the bottom row's 。) the top right corner is cut away, and a symbol placed
     * from the rectangle would stick out past the edge.
     */
    private fun keepInside(corner: TextView, width: Int, height: Int, radius: Float) {
        if (width == 0 || height == 0) return
        val r = minOf(radius, width / 2f, height / 2f)
        // The glyph's own top right corner, measured from the key's top right corner.
        val bounds = Rect()
        corner.paint.getTextBounds(corner.text.toString(), 0, corner.text.length, bounds)
        val right = (corner.measuredWidth - corner.paddingLeft - bounds.right).toFloat()
        val top = (corner.baseline + bounds.top).toFloat()
        fun inside(t: Float): Boolean {
            val x = r - (right + t)
            val y = r - (top + t)
            return x <= 0 || y <= 0 || x * x + y * y <= r * r
        }
        var t = 0f
        while (!inside(t) && t < r) t += 0.5f
        corner.translationX = -t
        corner.translationY = t
    }

    private fun weighted(views: List<Pair<View, Float>>) = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        for ((v, w) in views) addView(v, LayoutParams(0, LayoutParams.MATCH_PARENT, w))
    }

    private fun rowParams() = LayoutParams(LayoutParams.MATCH_PARENT, dp(row))

    private enum class Style { LETTER, FUNCTION, PILL }

    private fun pressable(color: Int, radius: Float): RippleDrawable {
        val shape = GradientDrawable().apply { cornerRadius = radius; setColor(color) }
        val mask = GradientDrawable().apply { cornerRadius = radius; setColor(Color.WHITE) }
        return RippleDrawable(ColorStateList.valueOf(pressedColor), shape, mask)
    }

    /**
     * A key: its face with rounded corners (letters and shift / delete) or a pill (the bottom row's
     * function keys), inside a frame that makes the gap to the next key; a symbol in the corner
     * types on a long press. A key with `preview` shows its character in the popup while pressed;
     * held long, the popup turns to the corner symbol, half-width and full-width side by side; sliding
     * picks one, typed on release (sliding off before that cancels).
     * The keyboard tracks the finger itself, so a long press takes [LONG_PRESS] ms whatever the
     * phone's touch-and-hold delay; `onRelease` runs when the finger lifts or slides off.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun key(
        label: String, id: String, style: Style = Style.LETTER, hint: Char? = null, preview: Boolean = false,
        onLongPress: (() -> Unit)? = null, onRelease: (() -> Unit)? = null, onPress: (() -> Unit)? = null, iconRes: Int = 0, textSize: Float = 0f,
        ink: Int = 0, onClick: () -> Unit,
    ): View {
        val function = style != Style.LETTER
        val color = if (ink != 0) ink else if (function) functionText else textColor
        val face = FrameLayout(context).apply {
            contentDescription = id
            background = pressable(if (function) functionColor else keyColor, dp(if (style == Style.PILL) 21 else 8).toFloat())
            setOnClickListener { onClick() }
            // Without a finger on it (TalkBack), a long press types the symbol at once.
            if (onLongPress != null) setOnLongClickListener { v -> if (!popup.flip(v)) onLongPress(); true }
        }
        faces += face
        var shown = 0
        var held = false
        var off = false
        val hold = Runnable { held = true; if (!popup.flip(face)) onLongPress?.invoke() }
        face.setOnTouchListener { v, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    held = false; off = false
                    v.drawableHotspotChanged(e.x, e.y)
                    v.isPressed = true
                    if (preview) shown = popup.show(v, label, hint?.toString().orEmpty())
                    if (onLongPress != null) postDelayed(hold, LONG_PRESS)
                    onPress?.invoke()
                }
                MotionEvent.ACTION_MOVE -> if (preview && popup.flipped(shown)) popup.select(v, e.x)
                else if (!off && (e.x < -slop || e.y < -slop || e.x > v.width + slop || e.y > v.height + slop)) {
                    off = true
                    removeCallbacks(hold)
                    v.isPressed = false
                    if (preview) popup.hide(shown)
                    onRelease?.invoke()
                }
                MotionEvent.ACTION_UP -> {
                    removeCallbacks(hold)
                    v.isPressed = false
                    if (preview) {
                        popup.lift(v)
                        popup.choice(shown)?.let { listener.onSymbol(it) }
                        val last = shown
                        postDelayed({ popup.hide(last) }, 50)
                    }
                    if (!off) onRelease?.invoke()
                    if (!held && !off) v.performClick()
                }
                MotionEvent.ACTION_CANCEL -> {
                    removeCallbacks(hold)
                    v.isPressed = false
                    if (preview) { popup.lift(v); popup.hide(shown) }
                    if (!off) onRelease?.invoke()
                }
            }
            true
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
            val corner = TextView(context).apply {
                text = hint.toString()
                setTextColor(if (function) functionText else hintColor)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                setPadding(0, dp(1), dp(4), 0)
            }
            face.addView(corner, FrameLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END))
            val radius = dp(if (style == Style.PILL) 21 else 8).toFloat()
            face.addOnLayoutChangeListener { v, _, _, _, _, _, _, _, _ -> keepInside(corner, v.width, v.height, radius) }
        }
        return FrameLayout(context).apply {
            setPadding(dp(3), dp(4), dp(3), dp(4))
            addView(face, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
    }

    /**
     * The block of keys, which hands each finger to the nearest key: a tap in the gap between keys
     * (or on the blank ends of the asdf row) types that key, and the keys around the edge also take
     * taps up to [REACH] dp outside them, since a finger is not that precise. The finger is moved
     * onto the key's edge by the same amount for the whole touch, so sliding off still cancels.
     * Each finger goes to its own key, so fast typing with two thumbs works as before.
     */
    private inner class KeyArea : FrameLayout(context) {
        /** A finger on a key: where it is moved to, into the key's own coordinates. */
        private inner class Finger(val face: View, val dx: Float, val dy: Float)
        private val fingers = HashMap<Int, Finger>()

        override fun dispatchTouchEvent(e: MotionEvent): Boolean {
            if (keys.visibility != VISIBLE) return super.dispatchTouchEvent(e)
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    val i = e.actionIndex
                    nearest(e.getX(i), e.getY(i))?.let { fingers[e.getPointerId(i)] = it; send(it, MotionEvent.ACTION_DOWN, e, i) }
                }
                MotionEvent.ACTION_MOVE -> for (i in 0 until e.pointerCount) fingers[e.getPointerId(i)]?.let { send(it, MotionEvent.ACTION_MOVE, e, i) }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                    val i = e.actionIndex
                    fingers.remove(e.getPointerId(i))?.let { send(it, MotionEvent.ACTION_UP, e, i) }
                }
                MotionEvent.ACTION_CANCEL -> {
                    for (f in fingers.values) send(f, MotionEvent.ACTION_CANCEL, e, 0)
                    fingers.clear()
                }
            }
            return true
        }

        /** The key nearest to (x, y), within [REACH] dp of its face. */
        private fun nearest(x: Float, y: Float): Finger? {
            val reach = dp(REACH).toFloat()
            var best: Finger? = null
            var bestDistance = reach * reach
            val r = Rect()
            for (face in faces) {
                if (!face.isShown) continue
                face.getDrawingRect(r)
                offsetDescendantRectToMyCoords(face, r)
                val px = x.coerceIn(r.left.toFloat(), r.right - 1f)
                val py = y.coerceIn(r.top.toFloat(), r.bottom - 1f)
                val d = (px - x) * (px - x) + (py - y) * (py - y)
                if (d <= bestDistance) {
                    bestDistance = d
                    best = Finger(face, px - x - r.left, py - y - r.top)
                    if (d == 0f) break
                }
            }
            return best
        }

        private fun send(f: Finger, action: Int, e: MotionEvent, i: Int) {
            val event = MotionEvent.obtain(e.downTime, e.eventTime, action, e.getX(i) + f.dx, e.getY(i) + f.dy, e.metaState)
            f.face.dispatchTouchEvent(event)
            event.recycle()
        }
    }

    /**
     * The popup above the pressed key, drawn over the keyboard: the character large with the
     * long-press symbol small in its corner, as on the key; held long, it flips to the symbol on the
     * function keys' blue. One at a time: each press gets a number, and only the latest one shows.
     */
    private inner class KeyPopup : Drawable() {
        private var key: View? = null
        private var finger: View? = null
        private var press = 0
        private var main = ""
        private var corner = ""
        private var long = false
        /** Held: the symbol half-width and full-width (one choice when it has no other form), and the one under the finger. */
        private var options = listOf<String>()
        private var selected = 0
        private val keyBox = RectF()
        private val box = RectF()
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        private val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(1) / 2f; color = edgeColor }
        private val big = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; textSize = sp(32f) }
        private val small = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.RIGHT; textSize = sp(13f) }
        private val caption = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; textSize = sp(10f) }

        /** Shows `label` over `view`; returns this press's number. */
        fun show(view: View, label: String, hint: String): Int {
            val r = Rect()
            view.getDrawingRect(r)
            offsetDescendantRectToMyCoords(view, r)
            val w = maxOf(r.width() * 1.45f, dp(54).toFloat())
            val h = dp(64).toFloat()
            val left = (r.exactCenterX() - w / 2).coerceIn(dp(4).toFloat(), maxOf(dp(4).toFloat(), width - dp(4) - w))
            val top = maxOf(0f, r.top - dp(4) - h)
            box.set(left, top, left + w, top + h)
            keyBox.set(r)
            key = view; finger = view; main = label; corner = hint; long = false
            setBounds(0, 0, width, height)
            invalidateSelf()
            return ++press
        }

        /** Turns the popup of the press on `view` to its symbol; false when no finger is on `view`. */
        fun flip(view: View): Boolean {
            if (finger != view) return false
            if (key == view && corner.isNotEmpty()) {
                long = true
                val c = corner.codePointAt(0)
                options = if (c in 0x21..0x7e) listOf(corner, String(Character.toChars(c + 0xfee0))) else listOf(corner)
                selected = 0
                // The half-width one over the key, the full-width one beside it (to the left at the right edge).
                val cell = box.width()
                val left = (keyBox.centerX() - cell / 2).coerceIn(dp(4).toFloat(), maxOf(dp(4).toFloat(), width - dp(4) - cell * options.size))
                box.set(left, box.top, left + cell * options.size, box.bottom)
                invalidateSelf()
            }
            return true
        }

        /** The finger on `view` is at `x` (in the key's coordinates): picks the choice under it. */
        fun select(view: View, x: Float) {
            if (finger != view || !long) return
            val cell = box.width() / options.size
            val i = ((x + keyBox.left - box.left) / cell).toInt().coerceIn(0, options.size - 1)
            if (i != selected) { selected = i; invalidateSelf() }
        }

        /** What the press `number` types on release: the chosen symbol once held, else null. */
        fun choice(number: Int) = if (flipped(number)) options[selected] else null

        /** The finger has left `view` (released or cancelled). */
        fun lift(view: View) { if (finger == view) finger = null }

        fun flipped(number: Int) = number == press && key != null && long

        fun hide(number: Int) {
            if (number != press || key == null) return
            key = null
            invalidateSelf()
        }

        override fun draw(canvas: Canvas) {
            if (key == null) return
            val radius = dp(14).toFloat()
            fill.color = if (long) functionColor else keyColor
            fill.setShadowLayer(dp(5).toFloat(), 0f, dp(2).toFloat(), shadowColor)
            if (long && options.size > 1) {
                fill.color = keyColor
                canvas.drawRoundRect(box, radius, radius, fill)
                canvas.drawRoundRect(box, radius, radius, edge)
                fill.clearShadowLayer()
                val cell = box.width() / options.size
                for ((i, text) in options.withIndex()) {
                    val r = RectF(box.left + i * cell, box.top, box.left + (i + 1) * cell, box.bottom)
                    if (i == selected) {
                        fill.color = functionColor
                        canvas.drawRoundRect(RectF(r.left + dp(3), r.top + dp(3), r.right - dp(3), r.bottom - dp(3)), radius - dp(3), radius - dp(3), fill)
                    }
                    big.color = if (i == selected) functionText else textColor
                    canvas.drawText(text, r.centerX(), r.centerY() - dp(4) - (big.descent() + big.ascent()) / 2, big)
                    caption.color = if (i == selected) functionText else hintColor
                    canvas.drawText(if (i == 0) "半角" else "全角", r.centerX(), r.bottom - dp(6) - caption.descent(), caption)
                }
                return
            }
            canvas.drawRoundRect(box, radius, radius, fill)
            canvas.drawRoundRect(box, radius, radius, edge)
            big.color = if (long) functionText else textColor
            canvas.drawText(if (long) corner else main, box.centerX(), box.centerY() - (big.descent() + big.ascent()) / 2, big)
            val sub = if (long) main else corner
            if (sub.isNotEmpty()) {
                small.color = if (long) functionText else hintColor
                small.alpha = if (long) 0xb3 else 0xff
                canvas.drawText(sub, box.right - dp(8), box.top + dp(5) - small.ascent(), small)
            }
        }

        override fun setAlpha(alpha: Int) {}
        override fun setColorFilter(colorFilter: ColorFilter?) {}
        @Deprecated("Deprecated in Java")
        override fun getOpacity() = PixelFormat.TRANSLUCENT
    }

    companion object {
        /** The height of a row of keys, in dp: as on Gboard. */
        const val ROW = 45

        /** How long a key is held for its long press, in ms: Android's short touch-and-hold delay. */
        const val LONG_PRESS = 400L

        /** How far outside its face, in dp, a key around the edge of the block still takes a tap. */
        const val REACH = 32

        /** What each letter does while Ctrl is held (Ctrl+V cuts, as the person asked). */
        val SHORTCUTS = mapOf('a' to Action.SELECT_ALL, 'c' to Action.COPY, 'v' to Action.CUT, 'y' to Action.REDO, 'z' to Action.UNDO)

        /** Two taps on shift closer than this, in ms, turn on caps lock. */
        const val DOUBLE_TAP_MS = 400L

        /** The height of a row of keys on a short landscape screen, in dp. */
        const val ROW_LOW = 40

        /** The widest the keys get, in dp: about a large phone's keyboard in portrait, a little wider. */
        const val MAX_WIDTH = 640

        /** The symbol a long press on each letter types, as on Gboard. */
        val HINTS = mapOf(
            'q' to '%', 'w' to '\\', 'e' to '|', 'r' to '=', 't' to '[', 'y' to ']', 'u' to '<', 'i' to '>', 'o' to '{', 'p' to '}',
            'a' to '@', 's' to '#', 'd' to '$', 'f' to '-', 'g' to '&', 'h' to '_', 'j' to '+', 'k' to '(', 'l' to ')',
            'z' to '*', 'x' to '"', 'c' to '\'', 'v' to ':', 'b' to ';', 'n' to '!', 'm' to '?',
        )
    }
}
