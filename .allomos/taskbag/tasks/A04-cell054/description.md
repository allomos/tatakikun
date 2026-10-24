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

**Evidence.**
- Android, merged into master: on a screen whose smallest side is 600 dp or more, the bottom row starts with a Ctrl key (the space bar is narrower to make room); phones have no Ctrl key.
- Holding Ctrl highlights a, c, v, y, z (light and dark mode); releasing it, or sliding off, removes the highlight. A tap alone does nothing.
- While Ctrl is held, the letter runs its shortcut instead of typing; what is being typed is finished first. Select all, copy and cut use the input connection's context menu actions; undo and redo send Ctrl+Z and Ctrl+Shift+Z, as a hardware keyboard does.
- Checked on an emulator set to a tablet size (1600×2560, 320 dpi) in the app's text field: a selected all; c then paste gave `hello world hello world `; v emptied the field; z brought the text back; y emptied it again. The emulator cannot hold one finger while tapping with another (`adb input` cancels the hold), so for this check a test-only build latched Ctrl on a tap; the real build was used for the highlight screenshots. Holding Ctrl with one finger and tapping with another needs a person on a real tablet.
- Undo/redo work in Android text fields (EditText); apps with their own editors may ignore Ctrl+Z.
- iPad: not done. Apple's keyboard extension API has no select all, undo or redo, and copying or cutting needs Full Access (`RequestsOpenAccess`, now false). Question for the person under Waiting.
