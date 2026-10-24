**Outcome.** On Android and iOS a tap that lands between keys (gaps, the blank ends of the asdf row) types the nearest key instead of nothing; the keys around the edge of the key block also take taps up to about 32 dp/pt outside them.

**Done means.** On the emulator, taps in the gaps and just outside the edge keys type the nearest key; a tap on a key still types it; fast two-finger typing still works; sliding off a key still cancels.

**Notes.** Asked by the person 2026-10-24.

## Evidence

- 2026-10-24, claude-tap-reach: Release v0.6.11 approved by the person's line 'when finished, move the item about down to the last item, need no test, and call alm guide github release' (2026-10-24 ~20:00 JST). Tag v0.6.11 on a465a85; https://github.com/allomos/tatakikun/releases/tag/v0.6.11 (200). Assets: Tatakikun-0.6.11.pkg (sha256 58b8e709…3a9e49) + .sha256, Tatakikun-0.6.11-android.apk (sha256 e6f91c37…40505a, signed 05d10759…bdb41) + .sha256. Packs rebuilt before the build (build/dict deleted, scripts/build-packs.sh). APK check: scripts/test-android.sh on emulator-5554, 9/9 passed. Installed on this Mac from the downloaded release: checksum OK, installer -target CurrentUserHomeDirectory, launchctl kickstart; installed version 0.6.11, Tatakikun running.
