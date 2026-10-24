**Outcome.** On the Android and iOS keyboards, double-tapping shift turns on caps lock: every letter types in uppercase until shift is tapped again. The shift key shows that caps lock is on, so it looks different from a single shift.

**Done means.**
- Single tap on shift: the next letter only is uppercase, then it goes back to lowercase (as now).
- Two quick taps on shift: caps lock is on; several letters in a row all type in uppercase, and the shift key shows the caps lock look (for example a filled arrow with a bar under it, as in Gboard and the iOS keyboard).
- One tap on shift while caps lock is on: back to lowercase.
- Works on the Android keyboard and the iOS keyboard, in light and dark mode.

**Notes.**
- Uppercase letters with caps lock go through the engine like single-shift letters do now (the raw letter string stays a candidate).
- The double-tap time window and the exact caps lock look are routine choices for whoever works the task.

**Evidence.**
- iOS: `scripts/build-ios.sh test` passes all 6 UI tests, including the new `testShiftOnceAndCapsLock` (one tap: next letter only; real double tap: caps lock, "OK" stays uppercase; one more tap: off; the field holds `HiOKa`).
- Android, on an emulator (Pixel 7, API 34): one tap on shift then h, i types "Hi" and shift goes back to lowercase; the keys show capitals while shift is on.
- Android caps lock was not confirmed on the emulator: the Mac was under heavy load (load average 35–50), the emulator stalled ("System UI isn't responding"), and `adb input tap` cannot tap twice inside the window. The Android code uses the same three states and 400 ms window as iOS. A person checks it by hand (steps).
- iOS now updates the letter keys and shift in place instead of rebuilding the keyboard: rebuilding under the finger lost the second tap of a double tap (the first UI test run showed this).
