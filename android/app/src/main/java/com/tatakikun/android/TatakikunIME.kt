package com.tatakikun.android

import android.inputmethodservice.InputMethodService
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo

/**
 * The Tatakikun input method: the same engine and Composer as on the Mac, through JNI. The letters
 * being typed show as composing text (underlined) in the field; the candidates in the keyboard.
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

    override fun onCreateInputView(): View = KeyboardView(this, this).also { view = it }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        view?.showsNextKeyboard = shouldOfferSwitchingToNextInputMethod()
        view?.show(null)
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

    override fun onNextKeyboard() {
        switchToNextInputMethod(false)
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
            if (state.composing) ic.setComposingText(state.input, 1)
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
