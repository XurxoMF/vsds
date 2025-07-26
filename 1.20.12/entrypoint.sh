#!/bin/sh
set -e

# Ensure UID and GID are correctly set and change them is the user changed them
if [ ! "$(id -u vintagestory)" -eq "$UID" ]; then usermod -o -u "$UID" vintagestory ; fi
if [ ! "$(id -g vintagestory)" -eq "$GID" ]; then groupmod -o -g "$GID" vintagestory ; fi

# Continue with the container run command
exec "$@"
