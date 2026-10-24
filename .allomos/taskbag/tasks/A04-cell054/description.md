**Outcome.** On a tablet (iPad, Android tablet; detected by the keyboard), the Tatakikun keyboard has a Ctrl key. While Ctrl is held down, the keys a, c, v, y and z are highlighted, and pressing one of them runs its shortcut: Ctrl+A select all, Ctrl+C copy, Ctrl+V cut, Ctrl+Y redo, Ctrl+Z undo.

**Done means.**
- On an iPad and an Android tablet the keyboard shows a Ctrl key; on phones it does not.
- Holding Ctrl (pressed, not tapped) highlights a, c, v, y, z; releasing Ctrl removes the highlight.
- While Ctrl is held: a selects all text in the field, c copies the selection, v cuts the selection, y redoes, z undoes; no letter is typed and no candidate is shown.
- Tapping Ctrl alone (press and release without another key) does nothing harmful: no letter, no lasting mode.
- Works in light and dark mode, on both platforms.

**Notes.**
- Ctrl+V is cut, as the person asked (not paste); Ctrl+X is not part of this task.
- Pad detection (iOS user interface idiom; Android smallest screen width or similar), the Ctrl key's place in the layout and the highlight look are routine choices for whoever works the task.
- Undo/redo may depend on what the host app supports through the input method APIs; record what works where under Evidence.
- **iPad, decided by the approver (2026-10-25):** turn on Full Access (`RequestsOpenAccess` true) and give iPad a Ctrl key with c (copy) and v (cut) only; a, y and z are not highlighted on iPad, since Apple's keyboard API cannot select all, undo or redo. As with A04-tuna688, tell users why Full Access is needed: the Tatakikun app explains, in plain words and before iOS shows its "Allow Full Access" warning, what Full Access is used for (copy and cut with Ctrl; reading settings made in the app) and that typed text is not sent anywhere. Without Full Access the Ctrl key still shows but c and v do nothing harmful (or Ctrl is hidden; routine choice, record it).

**Evidence.**
- Android, merged into master: on a screen whose smallest side is 600 dp or more, the bottom row starts with a Ctrl key (the space bar is narrower to make room); phones have no Ctrl key.
- Holding Ctrl highlights a, c, v, y, z (light and dark mode); releasing it, or sliding off, removes the highlight. A tap alone does nothing.
- While Ctrl is held, the letter runs its shortcut instead of typing; what is being typed is finished first. Select all, copy and cut use the input connection's context menu actions; undo and redo send Ctrl+Z and Ctrl+Shift+Z, as a hardware keyboard does.
- Checked on an emulator set to a tablet size (1600×2560, 320 dpi) in the app's text field: a selected all; c then paste gave `hello world hello world `; v emptied the field; z brought the text back; y emptied it again. The emulator cannot hold one finger while tapping with another (`adb input` cancels the hold), so for this check a test-only build latched Ctrl on a tap; the real build was used for the highlight screenshots. Holding Ctrl with one finger and tapping with another needs a person on a real tablet.
- Undo/redo work in Android text fields (EditText); apps with their own editors may ignore Ctrl+Z.
- iPad, merged into master (eee7352): Full Access is requested (`RequestsOpenAccess` true). On iPad the bottom row of the letter layer starts with a ctrl key (the space bar is narrower); the symbols layer and iPhone have none. Holding ctrl highlights c and v (light and dark mode); c copies the selected text to the clipboard, v copies it and deletes it; other letters do nothing while ctrl is held; what is being typed is inserted first. A letter that went down while ctrl was held still runs its shortcut if ctrl is let go first. Without Full Access, c and v leave the clipboard alone and the candidate bar says "Copy and cut need Full Access: see the Tatakikun app".
- The iPad setup screen has an "Allow Full Access" row (opens Settings) with an explanation shown before iOS's own warning: Full Access is only for copy and cut with ctrl, Tatakikun has no network code and what you type stays on the device.
- Checked on the iPad Pro 11-inch (M4) simulator, iOS 18, in the app's Try it field, light and dark mode: hello selected, ctrl, c left the text, v emptied the field, a typed nothing, then Paste from the field's menu gave hello back. As on Android, the test tools cannot hold one finger while tapping with another, so a test-only build (not committed) latched ctrl on a tap; the committed UI test `testCtrlKeyOnlyOnPad` checks the key is there on iPad and absent on iPhone. The iPhone UI tests (12) pass. Not checked: the real keyboard extension in another app (needs a person: the simulator hides third-party keyboards from tests), and whether every app reports its selection to keyboards (`selectedText`).
