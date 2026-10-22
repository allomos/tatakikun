package com.tatakikun.android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/** Tells how to turn the keyboard on, and gives a field to try it in. */
class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 16f, resources.displayMetrics).toInt()
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(pad, pad * 2, pad, pad) }
        layout.addView(TextView(this).apply { text = getString(R.string.app_name); setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f) })
        layout.addView(TextView(this).apply { text = getString(R.string.setup); setPadding(0, pad, 0, pad) })
        layout.addView(Button(this).apply {
            text = getString(R.string.open_settings)
            setOnClickListener { startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)) }
        })
        layout.addView(Button(this).apply {
            text = getString(R.string.choose_keyboard)
            setOnClickListener { (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker() }
        })
        layout.addView(EditText(this).apply { id = R.id.try_field; hint = getString(R.string.try_hint); minLines = 3 })
        setContentView(layout)
    }
}
