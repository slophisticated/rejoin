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

---

## v0.3.3 — Fix disappearing config & stuck "ingame" status

- `core/config.lua serializeTable`: array/numeric keys now serialize as real integer keys (`[1] = ...`) instead of string keys (`["1"] = ...`). Previously a save rewrote `instances` with string keys which `ipairs` could not read, so a later save blanked the config to `instances = {}`.
- `managers/instance.lua load` + `core/setup_wizard.lua nextId`: read with `pairs()` and normalize mixed string/number keys so configured instances always survive a reload.
- `managers/apk.lua isRunning`: process matching is now anchored to the START of the process command (`^<pkg>($|:)`) instead of a loose substring. This fixes status getting stuck at "ingame" after an app is closed (a leftover process containing the name as a substring no longer counts), so the monitor now reports `offline` and recovers/relaunches the app.

---

## v0.3.4 — Launch one clone at a time

- `Recovery.waitUntilRunning()` added: after launching a clone, poll `APK.isRunning()` until its process is observed (then a short settle pause) or a timeout elapses.
- "Launch All" (menu 1) now launches clones ONE AT A TIME — it waits for each clone to reopen before starting the next, so multiple floating-window clones each get a chance to appear instead of one being crowded out (previously a fixed 3s pause / then a monitor that still reported "starting").
- New settings (Settings menu → `14) Edit launch wait settings`): `launchWaitInterval` (3s), `launchWaitTimeout` (90s), `launchSettleDelay` (5s).

---

## v0.3.5 — Fix launch hang (isRunning never matched)

- Fixed `managers/apk.lua escapeRegex`: the replacement was producing `%.` (percent-dot) instead of `\.` (backslash-dot), so the `pgrep -f '^com\.apengjers\.v6($|:)'` pattern never matched and `isRunning` always returned false. `waitUntilRunning` then waited a full timeout per clone, making "Launch All" appear stuck (repeating `pidof`/`pgrep`/`ps`).
- `escapeRegex` now emits backslash escapes (`\.`) valid for POSIX ERE (`pgrep -f`).
- `ps -A` fallback compares the process command start with a plain (non-regex) check (`cmd == pkg or cmd starts with pkg..":"`) instead of feeding an ERE pattern to Lua's `string.match`.

---

## v0.3.6 — Count-based launch wait + public link joins the map

- New `managers/apk.lua APKManager.countProcess(name)`: counts running processes for a base name (e.g. `com.roblox.client`) via pgrep/pidof/ps. App Cloner clones all run as `com.roblox.client`, so the count tracks how many clones are actually up regardless of the renamed package.
- `Recovery.waitUntilRunning` now accepts a `target` count: it waits until `countProcess(processCheckName) >= target` (then a settle pause) or a (shortened) timeout. Default `launchWaitTimeout` lowered 90→30s so a failed detection never hangs "Launch All".
- "Launch All" (`main.lua`) records a baseline `countProcess` before the loop, then after launching clone `i` waits for `count >= baseline + i` before starting the next — launching one clone at a time, each confirmed open before the next.
- New setting `processCheckName` (default `com.roblox.client`) — the base process counted; editable via Settings → `14) Edit launch wait settings`.
- `utils/roblox_link.lua`: public game links now convert to `roblox://placeId=<placeId>` (deep link that drops straight into the game/map) instead of `roblox://experiences/<placeId>` (which only opened the game's page on mobile).

---

## v0.3.7 — Root (su) process detection + direct-join deep link

- **Root required** (`utils/shell.lua`): every shell command now runs through `su -c '...'` when `useRoot` is enabled (default `true`). This is the real fix for "detection looks broken": on a rooted device Android 11+, Termux running as a NORMAL user cannot see other apps' processes, so every `pidof`/`pgrep`/`ps` probe returned empty and every instance looked offline. Running as root (Magisk) makes the Monitor see the real per-clone processes again. Set `useRoot = false` on a non-root device.
- **Correct process model**: App Cloner clones keep their OWN package process name (`com.apengjers.v3`, etc. — verified from the clone APK manifest and on-device `su -c "pidof com.apengjers.v3"`), NOT `com.roblox.client` as v0.3.6 assumed. `com.roblox.client` is only the class/activity base, not the process name.
- `managers/apk.lua`: new `APK.countRunning(packages)` counts how many of the given configured packages report `isRunning` — accurate per-clone count without needing a shared base name.
- `Recovery.waitUntilRunning` + "Launch All": replaced the `countProcess(processCheckName)` target with `targetCount` of running instances (`countRunning >= baseline + i`). Drops the now-unneeded `processCheckName` setting.
- `utils/roblox_link.lua`: public game links now convert to **`robloxmobile://placeID=<placeId>`** (capital `ID`) — the scheme the clones register and that `ActivityProtocolLaunch` handles by joining the map directly — instead of `roblox://placeId=<placeId>` which only opened the game's page. `robloxmobile://` added to the accepted-scheme whitelist.
- New setting `useRoot` (default `true`), editable via Settings → `14) Edit launch wait settings`.

---

## v0.3.8 — Quiet monitor + direct-join deep link

- `core/logger.lua`: new console `logLevel` filter (default `INFO`). `Logger.debug` lines are now hidden unless `logLevel = "DEBUG"`, fixing the monitor being flooded with `su -c ...` and per-probe `pidof`/`pgrep`/`ps` debug spam every cycle. Set to DEBUG via Settings → `15) Edit logLevel` for troubleshooting.
- `managers/status.lua printSummary`: status table rewritten as one compact line — e.g. `1=starting  2=running  3=freeze  4=recovery` — instead of the verbose multi-line log-style output.
- New setting `logLevel` (default `INFO`), editable via Settings → `15) Edit logLevel`.
- `utils/roblox_link.lua`: public game links now convert to **`roblox://experiences/start?placeId=<placeId>`** — the deep link form Roblox uses to START/join the game directly. Earlier formats (`roblox://experiences/<id>`, `roblox://placeId=...`, `robloxmobile://placeID=`) only opened the game's page on this client. Example: `https://www.roblox.com/games/110776611234/Steal-An-Egg` → `roblox://experiences/start?placeId=110776611234`.

---

## v0.3.9 — Force ActivityProtocolLaunch for direct join

- `utils/android.lua openURL`: public-game links are now delivered by forcing the clone's **`ActivityProtocolLaunch`** handler via `am start -a VIEW -d '<url>' -n <pkg>/com.roblox.client.ActivityProtocolLaunch`, instead of the old `-p <pkg>` (which lets Android pick an activity that only shows the game's page). Falls back to `-p <pkg>` then an untargeted VIEW, logging which strategy ran.
- `utils/roblox_link.lua`: public links convert back to **`robloxmobile://placeID=<placeId>`** — the form that `ActivityProtocolLaunch` on the App Cloner clones joins straight into the map (verified on the cloned Roblox activity set and the Android direct-join path).

## Upcoming

- Shell Wrapper
- Android Wrapper
- Config System
- Setup Wizard