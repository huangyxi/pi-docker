#!/bin/sh
set -e

PI_WEB_PATH=${PI_WEB_PATH:-/usr/local/bin/pi-web}

if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
	set -- "$PI_WEB_PATH" "$@"
elif [ -z "$(command -v "$1")" ] || { [ -f "$1" ] && [ ! -x "$1" ]; }; then
	set -- node "$@"
fi

exec "$@"
