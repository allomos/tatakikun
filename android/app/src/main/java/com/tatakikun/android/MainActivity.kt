package com.tatakikun.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast

/**
 * The settings screen: a header with sample candidates, the two setup steps with whether each is
 * done (checked again whenever the screen comes back), the language packs and version, and a
 * field to try the keyboard in.
 */
class MainActivity : Activity() {
    /** Light and dark colours, from one purple ramp. */
    private class Palette(dark: Boolean) {
        val page = if (dark) 0xFF1B1B1F.toInt() else 0xFFFBFAFF.toInt()
        val text = if (dark) 0xFFE6E1E5.toInt() else 0xFF1C1B1F.toInt()
        val secondary = if (dark) 0xFFA9A6B0.toInt() else 0xFF5F5E66.toInt()
        val divider = if (dark) 0x22FFFFFF else 0x1F000000
        val heroBg = if (dark) 0xFF2F2A5C.toInt() else 0xFFEEEDFE.toInt()
        val heroTitle = if (dark) 0xFFEEEDFE.toInt() else 0xFF26215C.toInt()
        val heroText = if (dark) 0xFFCECBF6.toInt() else 0xFF3C3489.toInt()
        val chipBg = if (dark) 0xFF3C3489.toInt() else Color.WHITE
        val accent = if (dark) 0xFFAFA9EC.toInt() else 0xFF534AB7.toInt()
        val done = if (dark) 0xFF97C459.toInt() else 0xFF3B6D11.toInt()
        val pillBg = if (dark) 0xFF3C3489.toInt() else 0xFFEEEDFE.toInt()
        val pillText = if (dark) 0xFFEEEDFE.toInt() else 0xFF3C3489.toInt()
        val ripple = if (dark) 0x33FFFFFF else 0x1F000000
    }

    private class Row(val view: LinearLayout, val icon: ImageView, val title: TextView, val detail: TextView)

    private lateinit var palette: Palette
    private lateinit var enableRow: Row
    private lateinit var chooseRow: Row

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dark = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        palette = Palette(dark)

        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(16), 0, dp(16), dp(24)) }
        column.addView(hero())

        column.addView(section(R.string.section_setup))
        enableRow = row(R.drawable.ic_step_todo, R.string.step_enable) {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }
        chooseRow = row(R.drawable.ic_step_todo, R.string.step_choose) {
            (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
        }
        column.addView(enableRow.view)
        column.addView(divider())
        column.addView(chooseRow.view)

        column.addView(section(R.string.section_keyboard))
        val packs = assets.list("packs").orEmpty()
        val packNames = Languages.all.filter { it.first in packs }
        lateinit var packsRow: Row
        val count = pill("")
        fun showLanguages() {
            val on = packNames.filter { it.first !in Languages.turnedOff(this) }
            packsRow.detail.text = on.joinToString(" · ") { it.second }
            count.text = on.size.toString()
        }
        packsRow = row(R.drawable.ic_language, R.string.language_packs) { chooseLanguages(packNames) { showLanguages() } }
        packsRow.view.addView(count)
        showLanguages()
        column.addView(packsRow.view)
        column.addView(divider())
        column.addView(longPressRow())
        column.addView(divider())
        val aboutRow = row(R.drawable.ic_info, R.string.about) {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(getString(R.string.project_url))))
        }
        aboutRow.detail.text = getString(R.string.about_detail)
        aboutRow.view.addView(TextView(this).apply {
            text = "v" + packageManager.getPackageInfo(packageName, 0).versionName
            setTextColor(palette.secondary); setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        }, aboutRow.view.childCount - 1)
        column.addView(aboutRow.view)

        column.addView(section(R.string.section_try))
        column.addView(EditText(this).apply {
            id = R.id.try_field
            hint = getString(R.string.try_hint)
            minLines = 3
            gravity = Gravity.TOP or Gravity.START
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            setTextColor(palette.text); setHintTextColor(palette.secondary)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = GradientDrawable().apply { cornerRadius = dp(16).toFloat(); setStroke(dp(1), palette.accent) }
        })

        setContentView(ScrollView(this).apply {
            setBackgroundColor(palette.page)
            addView(column)
            // Edge to edge: keep the content clear of the status bar, the navigation bar and the keyboard.
            setOnApplyWindowInsetsListener { v, insets ->
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                v.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                // The keyboard came up for the try-it field: scroll the field above it.
                if (insets.isVisible(WindowInsets.Type.ime()) && findFocus() is EditText)
                    post { smoothScrollTo(0, column.height + paddingTop + paddingBottom - height) }
                insets
            }
        })
        edgeToEdge(dark)   // after setContentView: the insets controller needs the decor view
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    // The keyboard picker is a dialog over this screen: closing it brings back the focus, not onResume.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) refresh()
    }

    /** Shows each setup step as done or still to do. */
    private fun refresh() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val enabled = imm.enabledInputMethodList.any { it.packageName == packageName }
        val current = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.startsWith("$packageName/") == true
        show(enableRow, enabled, R.string.step_enable_todo)
        show(chooseRow, current, if (enabled) R.string.step_choose_todo else R.string.step_choose_after)
    }

    private fun show(row: Row, done: Boolean, todo: Int) {
        row.icon.setImageResource(if (done) R.drawable.ic_step_done else R.drawable.ic_step_todo)
        row.icon.imageTintList = ColorStateList.valueOf(if (done) palette.done else palette.accent)
        row.detail.text = getString(if (done) R.string.step_done else todo)
        row.detail.setTextColor(if (done) palette.done else palette.secondary)
    }

    /** Draws behind the system bars (Android 15 does this anyway), with their icons readable. */
    private fun edgeToEdge(dark: Boolean) {
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            val light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (dark) 0 else light, light)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                (if (dark) 0 else View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
        }
    }

    private fun hero() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(20), dp(22), dp(20), dp(20))
        background = GradientDrawable().apply { cornerRadius = dp(28).toFloat(); setColor(palette.heroBg) }
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            .apply { topMargin = dp(12) }
        addView(TextView(context).apply {
            text = getString(R.string.app_name)
            setTextColor(palette.heroTitle); setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        })
        addView(TextView(context).apply {
            text = getString(R.string.tagline)
            setTextColor(palette.heroText); setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding(0, dp(6), 0, dp(14))
            setLineSpacing(0f, 1.15f)
        })
        val chips = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL }
        for (sample in resources.getStringArray(R.array.hero_samples)) {
            chips.addView(TextView(context).apply {
                text = sample
                setTextColor(palette.heroText); setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setPadding(dp(12), dp(6), dp(12), dp(6))
                background = GradientDrawable().apply { cornerRadius = dp(16).toFloat(); setColor(palette.chipBg) }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                .apply { marginEnd = dp(8) })
        }
        addView(chips)
    }

    private fun section(text: Int) = TextView(this).apply {
        this.text = getString(text)
        setTextColor(palette.accent); setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        setPadding(dp(4), dp(24), dp(4), dp(6))
    }

    /** A settings row: icon, title over a detail line, and a chevron when it opens something. */
    private fun row(icon: Int, title: Int, onClick: (() -> Unit)?): Row {
        val image = ImageView(this).apply {
            setImageResource(icon); imageTintList = ColorStateList.valueOf(palette.secondary)
        }
        val titleView = TextView(this).apply {
            text = getString(title); setTextColor(palette.text); setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        }
        val detailView = TextView(this).apply { setTextColor(palette.secondary); setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f) }
        val texts = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(titleView); addView(detailView)
        }
        val view = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = dp(72)
            setPadding(dp(4), dp(10), dp(4), dp(10))
            addView(image, LinearLayout.LayoutParams(dp(24), dp(24)).apply { marginEnd = dp(18) })
            addView(texts, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        }
        if (onClick != null) {
            view.setOnClickListener { onClick() }
            view.background = RippleDrawable(ColorStateList.valueOf(palette.ripple), null,
                GradientDrawable().apply { cornerRadius = dp(16).toFloat(); setColor(Color.WHITE) })
            view.addView(ImageView(this).apply {
                setImageResource(R.drawable.ic_chevron); imageTintList = ColorStateList.valueOf(palette.secondary)
            }, LinearLayout.LayoutParams(dp(20), dp(20)).apply { marginStart = dp(8) })
        }
        return Row(view, image, titleView, detailView)
    }

    /**
     * The long-press delay: a slider from 200 to 600 ms in steps of 50; the keyboard uses it from
     * the next key held.
     */
    private fun longPressRow(): View {
        val row = row(R.drawable.ic_timer, R.string.long_press, null)
        fun show(ms: Int) { row.detail.text = getString(R.string.long_press_detail, ms) }
        val ms = KeySettings.longPressMs(this)
        show(ms)
        val slider = SeekBar(this).apply {
            contentDescription = getString(R.string.long_press)
            max = (KeySettings.MAX_MS - KeySettings.MIN_MS) / KeySettings.STEP_MS
            progress = (ms - KeySettings.MIN_MS) / KeySettings.STEP_MS
            progressTintList = ColorStateList.valueOf(palette.accent)
            thumbTintList = ColorStateList.valueOf(palette.accent)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar, value: Int, fromUser: Boolean) {
                    val chosen = KeySettings.MIN_MS + value * KeySettings.STEP_MS
                    KeySettings.setLongPressMs(this@MainActivity, chosen)
                    show(chosen)
                }
                override fun onStartTrackingTouch(bar: SeekBar) {}
                override fun onStopTrackingTouch(bar: SeekBar) {}
            })
        }
        (row.detail.parent as LinearLayout).addView(slider, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            .apply { topMargin = dp(4) })
        return row.view
    }

    /**
     * Turns each input language on or off: only the ones on give candidates, from the next time
     * the keyboard comes up. The last one on cannot be turned off.
     */
    private fun chooseLanguages(packs: List<Pair<String, String>>, changed: () -> Unit) {
        val checked = BooleanArray(packs.size) { packs[it].first !in Languages.turnedOff(this) }
        AlertDialog.Builder(this)
            .setTitle(R.string.languages_title)
            .setMultiChoiceItems(packs.map { it.second }.toTypedArray(), checked) { dialog, which, isChecked ->
                // The dialog may already have unchecked it in `checked`: count the others.
                if (!isChecked && packs.indices.none { it != which && checked[it] }) {
                    checked[which] = true
                    (dialog as AlertDialog).listView.setItemChecked(which, true)
                    Toast.makeText(this, R.string.languages_last, Toast.LENGTH_SHORT).show()
                    return@setMultiChoiceItems
                }
                checked[which] = isChecked
                Languages.setTurnedOff(this, packs.indices.filter { !checked[it] }.map { packs[it].first }.toSet())
                changed()
            }
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }

    private fun pill(text: String) = TextView(this).apply {
        this.text = text
        setTextColor(palette.pillText); setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        setPadding(dp(10), dp(3), dp(10), dp(3))
        background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(palette.pillBg) }
    }

    private fun divider() = View(this).apply {
        setBackgroundColor(palette.divider)
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1).apply { marginStart = dp(46) }
    }

    private fun dp(value: Int) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()
}
