# Changelog

## v0.1

Initial Project

- Project Structure
- Logger
- State Manager

---

## Unreleased / Bug fixes

- Launch APK: resolve real launchable activity (`cmd package resolve-activity`) with `monkey` fallback instead of hardcoded `.MainActivity`
- Process detection: `pidof` -> `pgrep` -> `ps` fallback chain for `isRunning`
- Monitor/recovery: correct success/failure handling around pcall + recovery boolean
- AutoExecute: treat global `config.autoExecute` as the shared script; per-instance path is an optional override
- Config template/working config: removed per-instance `autoExecutePath` in favour of the global AutoExecute path

---

## v0.2 — Android clone integration

- Auto-detect Roblox apps/clones during Setup Wizard via `cmd package resolve-activity` (works for renamed clones like `com.apengjers.v3`), plus optional `clonePackagePrefix` fast filter. Manual input still available.
- New `utils/roblox_link.lua`: safe game-link normalization
  - Public game links (`https://www.roblox.com/games/<placeId>`) optionally converted to `roblox://experiences/<placeId>`
  - Private server share links (`https://www.roblox.com/share?code=...&type=Server`) always opened as-is
  - Unknown/invalid links rejected safely
- Recovery now opens the instance game/private-server link through the normalizer before `am start VIEW`
- New settings: `clonePackagePrefix`, `normalizeGameLink`
- Main Menu: new shortcut `Launch + Join an instance` (choose an instance, launch its app and open its game link manually via `Recovery.launchAndJoin`)

---

## v0.3 — Launch-all + live per-instance status

- Main Menu `1) Launch + Join` now launches ALL configured instances (no manual pick), then immediately starts the monitor.
- New `managers/status.lua`: tracks per-instance status — `offline`, `starting`, `ingame`, `stuck`, `freeze`, `recovery`.
- Freeze detection via logcat ANR (`ANR in <package>`) with a grace-period fallback for `stuck`.
- `Recovery.relaunch()` force-stops and relaunches an app that has stayed frozen for `freezeTimeout` (default 300s, counted from when stuck/freeze was set).
- Monitor prints a live per-instance status table each cycle.
- New settings: `freezeTimeout`, `gracePeriod`, `anrCheckEnabled`.

---

## v0.3.1 — Fix launch & public link

- Launch now uses `monkey -p <pkg> -c LAUNCHER 1` FIRST (works in Termux without `cmd package resolve-activity`, which is unavailable in a non-root Termux shell); resolve-activity is only a fallback and no longer blocks the launch. Fixes instances not opening.
- Public game links are now ALWAYS converted to the deep link `roblox://experiences/<placeId>` so Roblox joins the place directly (an https URL only wakes the app without entering the game).
- Removed the `normalizeGameLink` setting/config/menu option (public links always deep-link; private `/share` links are still opened as-is).
- `utils/android.lua` launch updated to match the monkey-first strategy.

---

## v0.3.2 — Fix multiple-clone launch (App Cloner floating)

- Launch now targets the package EXPLICITLY first: `am start -a MAIN -c LAUNCHER -p <pkg>`. This starts each clone's own launcher task (works for App Cloner clones like `com.apengjers.v3`/`v4`, whose activities stay `com.roblox.client.*`) without depending on `cmd package resolve-activity`. `monkey` and resolve-activity remain fallbacks.
- "Launch All" (`main.lua` option 1) now pauses ~3s between instances so a floating-window clone appears before the next one is launched.
- `Android.openURL` now accepts an optional target package and opens the game link with `-p <pkg>` so a `roblox://experiences/<placeId>` deep link is delivered to the correct clone instead of a single shared default handler. Falls back to a non-targeted VIEW if the targeted start fails.

## Upcoming

- Shell Wrapper
- Android Wrapper
- Config System
- Setup Wizard