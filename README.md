# Rejoin Engine

Rejoin Engine adalah tools otomatisasi berbasis **Lua** yang berjalan di **Termux/Android** untuk mengelola banyak instance Roblox sekaligus: launching, monitoring, recovery, dan auto rejoin.

- Target: Android 10+, Termux, Lua 5.3 (atau LuaJIT), wajib **root** untuk beberapa aksi.
- Data disimpan lokal. Tanpa server, tanpa backend.

---

## Fitur

- **Multi Instance** — kelola banyak clone Roblox sekaligus, tiap instance punya:
  - `name` (nama instance)
  - `package` (package name clone, contoh `com.apengjers.v3`)
  - `privateServer` (link game / private server)
- **Auto Detect Clone** — Setup Wizard otomatis mendeteksi app/clone Roblox yang terinstall lewat `cmd package resolve-activity`, jadi clone dengan package name di-rename (mis. `com.apengjers.v3`) tetap ketahuan.
- **Launch tiap clone ditarget package** — membuka app clone lewat `am start -a MAIN -c LAUNCHER -p <pkg>` (menarget package eksplisit, jadi tiap clone dibuka sbg task sendiri; tidak butuh `cmd package resolve-activity` yang sering tidak tersedia di Termux non-root). `monkey` & resolve-activity hanya cadangan.
- **Monitor** — loop tunggal, cek tiap instance bergantian. Jika satu instance mati, hanya instance itu yang di-recovery; instance lain tetap diproses.
- **Live status per instance** — monitor menampilkan status tiap instance (`offline`, `starting`, `ingame`, `stuck`, `freeze`, `recovery`) setiap siklus.
- **Auto relaunch freeze** — app yang freeze/stuck lebih dari `freezeTimeout` (default 5 menit) otomatis di-force-stop & di-relaunch.
- **Recovery** — force-stop → launch → inject AutoExecute → buka game/private server → lanjut monitoring. Dicoba berulang (sesuai `recoveryRetries`).
- **AutoExecute (global)** — satu script dipakai semua instance.
- **Auto Join** — buka link game/private server dari tiap instance secara otomatis saat recovery.
- **Launch All + Monitor** — shortcut di Main Menu meluncurkan semua instance sekaligus lalu langsung masuk monitor.
- **CLI Menu** — Launch All, Instances, Settings, Logs, Start Monitor.

---

## Persyaratan

- Android 10+
- Termux + akses root (Magisk/KernelSU) untuk beberapa fitur
- Lua 5.3 (atau LuaJIT via `setup.sh`)
- Perintah shell Android: `am`, `pm`, `pidof`/`pgrep`/`ps`, `cp`

---

## Quickstart (Termux/Android)

1. Pastikan Termux punya Lua 5.3 + tools yang dibutuhkan.

2. Letakkan project di device, lalu jalankan setup (sekali):
   ```sh
   cd ~/rejoin
   chmod +x setup.sh && ./setup.sh
   ```

3. Jalankan tools:
   ```sh
   lua main.lua
   ```
   - Jika `config/config.lua` belum ada, **Setup Wizard** akan berjalan untuk mendeteksi/menambah instance.

4. Gunakan Main Menu untuk: **Instances**, **Settings**, **View Logs**, **Start Monitor**.

### Headless / automated run

- Mulai monitor langsung (tanpa menu):
  ```sh
  lua main.lua --headless --start-monitor
  ```
- Lewati wizard saat config belum ada:
  ```sh
  lua main.lua --no-wizard
  ```
- Simulasi tanpa efek samping shell (dry-run):
  ```sh
  lua main.lua --dry-run --headless --start-monitor
  ```

---

## Konsep: Package Name Clone

Tiap instance diidentifikasi lewat **package name**, bukan path folder.

Jika kamu pakai **app cloner** untuk menggandakan Roblox, setiap clone punya package name unik, contoh:

- `com.apengjers.v3`
- `com.apengjers.v4`
- `com.apengjers.v5`

Masukkan masing-masing package name ke `package` pada konfigurasi instance. Setup Wizard mode **Auto Detect** bisa menemukannya otomatis; mode **Manual** tersedia untuk instance yang tidak terdeteksi.

---

## Konfigurasi

File: `config/config.lua` (dibuat dari `config/template.lua` saat pertama kali).

Contoh:

```lua
return {
    -- AutoExecute bersifat GLOBAL: semua instance pakai script yang sama.
    autoExecute = "data/autoexecute/sample_AutoExecute.lua",
    monitorInterval = 5,       -- detik antar siklus monitor
    recoveryDelay = 3,         -- jeda antar percobaan recovery
    recoveryRetries = 3,       -- berapa kali recovery dicoba
    checkTimeout = 15,         -- detik menunggu app jadi sehat
    debug = true,
    autoExecuteDeployPath = "data/autoexecute",
    logPath = "data/rejoin.log",

    -- Filter cepat opsional untuk Auto Detect (mis. "com.apengjers."). Kosong = nonaktif.
    clonePackagePrefix = "",

    -- Deteksi freeze/stuck.
    freezeTimeout = 300,        -- detik app boleh freeze sebelum di-relaunch (5 menit)
    gracePeriod = 30,           -- detik setelah launch sebelum dinilai ingame vs stuck
    anrCheckEnabled = true,     -- deteksi ANR via logcat (best-effort, lebih andal dgn root)

    instances = {
        {
            id = 1,
            name = "Main",
            package = "com.apengjers.v3",
            privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg"
        },
        {
            id = 2,
            name = "Clone1",
            package = "com.apengjers.v4",
            privateServer = "https://www.roblox.com/share?code=62e6ddb1dc13094d872ea3f91ec427c8&type=Server"
        }
    }
}
```

### Format `privateServer`

Field `privateServer` (atau link game) menerima beberapa format:

| Jenis | Contoh |
| --- | --- |
| Public game link | `https://www.roblox.com/games/107778070777162/Steal-An-Egg` |
| Private server share link | `https://www.roblox.com/share?code=62e6ddb1dc13094d872ea3f91ec427c8&type=Server` |
| Roblox deep link | `roblox://experiences/107778070777162` |

Catatan link:
- Link dikirim ke `am start VIEW` setelah dinormalisasi dengan aman, dan **ditarget ke package clone** (`-p <pkg>`) agar deep link `roblox://` masuk ke clone yang benar, bukan handler default bersama.
- Link **private server `/share` selalu dibuka apa adanya** (tidak diubah).
- Link **game publik otomatis dikonversi ke deep link** `roblox://experiences/<placeId>` agar Roblox langsung join place (URL https hanya membangunkan app tanpa masuk game).
- Link yang tidak valid / berisi karakter berbahaya akan ditolak.

---

## Struktur Project

```
rejoin/
├── main.lua                    # entry point + main menu
├── setup.sh                    # setup skrip Termux
├── debug_probe.lua             # alat diagnostik: cek isRunning/isActive per clone
├── config/
│   ├── config.lua              # konfigurasi aktif (dibuat otomatis dr template)
│   ├── template.lua            # template konfigurasi
│   └── sample_AutoExecute.lua  # contoh script AutoExecute
├── core/
│   ├── config.lua              # loader & saver config
│   ├── logger.lua              # logger ke file
│   ├── state.lua               # state machine sederhana
│   ├── setup.lua               # pastikan config ada
│   ├── setup_wizard.lua        # wizard setup (auto-detect + manual)
│   ├── instances_cli.lua       # menu instances
│   ├── settings_cli.lua        # menu settings
│   ├── logs_cli.lua            # viewer log
│   └── runtime.lua             # flag runtime (dry-run)
├── managers/
│   ├── apk.lua                 # launch, force-stop, isRunning, resolve-activity
│   ├── instance.lua            # manager instance
│   ├── monitor.lua             # loop monitor
│   ├── recovery.lua            # engine recovery
│   └── autoexecute.lua         # deploy/inject AutoExecute
├── utils/
│   ├── shell.lua               # eksekusi shell
│   ├── android.lua             # wrapper am/intent
│   ├── file.lua, json.lua, timer.lua
└── data/
    ├── rejoin.log              # log runtime
    └── autoexecute/            # folder deploy AutoExecute
```

---

## Menu

### Main Menu
- `1) Launch All + Monitor` (launch semua instance + join game, langsung masuk monitor dengan status live)
- `2) Instances Manager`
- `3) Settings`
- `4) View Logs`
- `5) Start Monitor`
- `6) Exit`

### Instances Manager
- List, Add, Edit, Delete instance

### Settings
- `monitorInterval`, `recoveryDelay`, `recoveryRetries`, `checkTimeout`
- `debug` (toggle)
- `autoExecute` (global), `autoExecuteDeployPath`, `logPath`
- `clonePackagePrefix`
- `freezeTimeout` (detik sebelum relaunch app freeze), `gracePeriod`, `anrCheckEnabled`

---

## Logging

- File log: `data/rejoin.log` (path bisa diubah di Settings → `logPath`).
- Mencatat aktivitas: launch, recovery, join, error, sukses.
- Lihat via menu `View Logs`, atau langsung di device.

---

## Lisensi / Kontribusi

Project ini dikembangkan mandiri untuk keperluan otomatisasi. Gunakan dengan bijak sesuai ketentuan platform Roblox dan kebijakan masing-masing perangkat.
