package com.tatakikun.android

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.os.SystemClock
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo

/**
 * The Tatakikun input method: the same engine and Composer as on the Mac, through JNI. The letters
 * being typed show in a small box above the keyboard, like Gboard's pinyin (as composing text in the
 * field when the keyboard is hidden for a hardware keyboard); the candidates in the keyboard.
 * Keys come from the on-screen keyboard or a hardware keyboard.
 */
class TatakikunIME : InputMethodService(), KeyboardView.Listener {
    /** Opened in the background: the first start copies the language packs (about 70 MB). */
    @Volatile private var engine: Engine? = null
    private var view: KeyboardView? = null
    private var composing = false

    override fun onCreate() {
        super.onCreate()
        Thread { engine = Engine(Packs.folder(this).path, filesDir.path).takeIf { it.isOpen } }.start()
    }

    /**
     * Never the full-screen edit box Android shows in landscape: the application stays visible
     * above the keyboard (the keyboard keeps itself low and narrow enough there).
     */
    override fun onEvaluateFullscreenMode() = false

    override fun onCreateInputView(): View = KeyboardView(this, this).also { view = it }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        view?.show(null)
    }

    /** The application makes room for the keys only; the box with the letters lies over it, and lets touches through. */
    override fun onComputeInsets(outInsets: Insets) {
        super.onComputeInsets(outInsets)
        val view = view ?: return
        if (!isInputViewShown || isFullscreenMode) return
        val top = outInsets.contentTopInsets + view.panelTop
        outInsets.contentTopInsets = top
        outInsets.visibleTopInsets = top
        outInsets.touchableInsets = Insets.TOUCHABLE_INSETS_CONTENT
    }

    override fun onFinishInput() {
        // Leaving the field: insert what is typed, like the Mac input method.
        if (composing) engine?.finish()?.let { apply(it) }
        engine?.finish()
        super.onFinishInput()
    }

    // MARK: on-screen keys

    override fun onKey(kind: Int, char: Int) {
        if (!send(kind, char)) fallback(kind, char)
    }

    override fun onChoose(row: Int, column: Int) {
        engine?.choose(row, column)?.let { apply(it) }
    }

    override fun onSymbol(text: String) {
        val ic = currentInputConnection ?: return
        // As chosen, not turned to the language before the cursor; what is being typed goes in first.
        if (composing) engine?.finish()?.let { apply(it) }
        ic.commitText(text, 1)
    }

    override fun onAction(action: KeyboardView.Action) {
        val ic = currentInputConnection ?: return
        when (action) {
            KeyboardView.Action.SETTINGS ->
                startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            KeyboardView.Action.PASTE -> {
                if (composing) engine?.finish()?.let { apply(it) }
                ic.performContextMenuAction(android.R.id.paste)
            }
            KeyboardView.Action.LEFT -> sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_LEFT)
            KeyboardView.Action.RIGHT -> sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_RIGHT)
            else -> {
                if (composing) engine?.finish()?.let { apply(it) }
                when (action) {
                    KeyboardView.Action.SELECT_ALL -> ic.performContextMenuAction(android.R.id.selectAll)
                    KeyboardView.Action.COPY -> ic.performContextMenuAction(android.R.id.copy)
                    KeyboardView.Action.CUT -> ic.performContextMenuAction(android.R.id.cut)
                    // No context menu action for these: Ctrl+Z and Ctrl+Shift+Z, as a hardware keyboard sends them.
                    KeyboardView.Action.UNDO -> sendCtrl(KeyEvent.KEYCODE_Z, 0)
                    KeyboardView.Action.REDO -> sendCtrl(KeyEvent.KEYCODE_Z, KeyEvent.META_SHIFT_ON or KeyEvent.META_SHIFT_LEFT_ON)
                    else -> {}
                }
            }
        }
    }

    private fun sendCtrl(keyCode: Int, meta: Int) {
        val ic = currentInputConnection ?: return
        val state = KeyEvent.META_CTRL_ON or KeyEvent.META_CTRL_LEFT_ON or meta
        val now = SystemClock.uptimeMillis()
        ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0, state))
        ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0, state))
    }

    /** Keys the composer leaves to the application, from the on-screen keyboard. */
    private fun fallback(kind: Int, char: Int) {
        val ic = currentInputConnection ?: return
        when (kind) {
            Engine.Keys.BACKSPACE -> sendDownUpKeyEvents(KeyEvent.KEYCODE_DEL)
            Engine.Keys.SPACE -> ic.commitText(" ", 1)
            Engine.Keys.ENTER -> {
                val action = (currentInputEditorInfo?.imeOptions ?: 0) and EditorInfo.IME_MASK_ACTION
                if (action != EditorInfo.IME_ACTION_NONE && action != EditorInfo.IME_ACTION_UNSPECIFIED &&
                    (currentInputEditorInfo?.imeOptions ?: 0) and EditorInfo.IME_FLAG_NO_ENTER_ACTION == 0
                ) ic.performEditorAction(action) else sendKeyChar('\n')
            }
            Engine.Keys.DIGIT, Engine.Keys.OTHER -> ic.commitText(String(Character.toChars(char)), 1)
        }
    }

    // MARK: hardware keys

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (event.isCtrlPressed || event.isAltPressed || event.isMetaPressed) {
            if (composing) engine?.finish()?.let { apply(it) }
            return super.onKeyDown(keyCode, event)
        }
        val unicode = event.unicodeChar
        val (kind, char) = when (keyCode) {
            KeyEvent.KEYCODE_DEL -> Engine.Keys.BACKSPACE to 0
            KeyEvent.KEYCODE_ESCAPE -> Engine.Keys.ESCAPE to 0
            KeyEvent.KEYCODE_SPACE -> Engine.Keys.SPACE to 0
            KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> Engine.Keys.ENTER to 0
            KeyEvent.KEYCODE_DPAD_LEFT -> Engine.Keys.LEFT to 0
            KeyEvent.KEYCODE_DPAD_RIGHT -> Engine.Keys.RIGHT to 0
            KeyEvent.KEYCODE_DPAD_UP -> Engine.Keys.UP to 0
            KeyEvent.KEYCODE_DPAD_DOWN -> Engine.Keys.DOWN to 0
            KeyEvent.KEYCODE_TAB -> Engine.Keys.TAB to 0
            else -> when {
                unicode in 'a'.code..'z'.code || unicode in 'A'.code..'Z'.code -> Engine.Keys.LETTER to unicode
                unicode in '0'.code..'9'.code -> Engine.Keys.DIGIT to unicode
                unicode > 0x20 -> Engine.Keys.OTHER to unicode
                else -> return super.onKeyDown(keyCode, event)
            }
        }
        // Not composing, arrows and the like belong to the application.
        if (!composing && kind != Engine.Keys.LETTER && kind != Engine.Keys.SPACE && kind != Engine.Keys.OTHER) {
            return super.onKeyDown(keyCode, event)
        }
        return send(kind, char) || super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean =
        if (composing && event.unicodeChar != 0) true else super.onKeyUp(keyCode, event)

    // MARK: composing

    /** Sends a key to the composer and applies what it says; false when it leaves the key alone. */
    private fun send(kind: Int, char: Int): Boolean {
        val ic = currentInputConnection ?: return false
        // Still opening: the keys type as on a plain keyboard.
        val engine = engine ?: return false
        if (!composing) engine.setTextBefore(ic.getTextBeforeCursor(4, 0))
        val state = engine.key(kind, char) ?: return false
        apply(state)
        return state.handled
    }

    private fun apply(state: State) {
        val ic = currentInputConnection
        if (ic != null) {
            ic.beginBatchEdit()
            when {
                // Inserted text replaces the composing letters.
                state.commit != null -> ic.commitText(state.commit, 1)
                composing && !state.composing -> ic.commitText("", 1)
            }
            if (state.composing && !isInputViewShown) ic.setComposingText(state.input, 1)
            ic.endBatchEdit()
        }
        composing = state.composing
        view?.show(state)
    }

    override fun onDestroy() {
        engine?.close()
        super.onDestroy()
    }
}
