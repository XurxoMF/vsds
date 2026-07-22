#!/bin/sh
set -e

if [ "$(id -u)" = "0" ]; then
    # Change UID/GID only if running as root (i.e., on Linux)
    if [ "$UID" != "1000" ] || [ "$GID" != "1000" ]; then
        groupmod -o -g "$GID" vintagestory 2>/dev/null || true
        usermod -o -u "$UID" vintagestory 2>/dev/null || true
    fi
    exec gosu vintagestory "$@"
else
    # For non-root systems (like Docker Desktop on Mac/Windows)
    exec "$@"
fi
