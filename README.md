Rejoin Engine
=============

Rejoin Engine is a Lua-based automation tool designed to run on Termux/Android to manage multiple Roblox instances: launching, monitoring, recovery, and auto rejoin.

Quickstart (Termux/Android)
--------------------------

1. Ensure Termux has Lua 5.3 and necessary tools installed (am, pm, pidof, cp).

2. Place the project on the device and run:

   lua main.lua

   - If config/config.lua does not exist, the Setup Wizard will run to detect or add instances.

3. Use the Main Menu to configure Instances, Settings, View Logs, and Start the Monitor.

Headless / automated run
------------------------

- Start monitor immediately (headless):

  lua main.lua --headless --start-monitor

- Skip wizard when config missing:

  lua main.lua --no-wizard

Files of interest
-----------------

- main.lua — entry point and interactive main menu
- core/ — core modules (config, logger, setup, state, wizard, CLIs)
- managers/ — managers (instance, apk, monitor, recovery, autoexecute)
- utils/ — helpers (shell, file, timer, android, json)
- config/template.lua — config template
- data/ — runtime data (autoexecute deploys and logs)

Notes
-----
- Many operations use Android shell commands (am, pm, pidof) and may require root for some actions. Run on a Termux environment.
- AutoExecute deployment copies the script to a deploy folder; in-app injection may still require app-specific steps or root.
- Logger writes to data/rejoin.log by default; path configurable in settings.

If you want, the assistant can now run a dry-run simulation of monitor+recovery on the host (no shell commands) or prepare a sample config file for your device. Request which next.