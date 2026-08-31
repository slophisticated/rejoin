#!/data/data/com.termux/files/usr/bin/sh
# Rejoin Engine launcher.
#
# Run the engine THROUGH this wrapper so Ctrl+C actually stops it. The monitor loop
# spends almost all its time inside os.execute/io.popen (ps, pidof, cookie scan, ...),
# and POSIX blocks SIGINT while inside system()/popen() -> a raw `lua main.lua` often
# swallows Ctrl+C (the default SIGINT action is unreliable here). This shell wrapper
# catches Ctrl+C itself and kill(1)s the Lua child, which works regardless of what the
# child is doing.
#
# Usage:   sh run.sh [--flags...]
#          (or chmod +x run.sh && ./run.sh ...)
# Ctrl+C in THIS terminal stops the engine; no need to open a second session.

cd "$HOME/rejoin" || exit 1
lua main.lua "$@" &
PID=$!
trap 'kill -TERM "$PID" 2>/dev/null; exit 0' INT TERM
wait "$PID"
