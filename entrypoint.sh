#!/bin/sh
set -e

PI_WEB_PATH=/app/bin/pi-web

if [ "$#" -eq 0 ] || [ "${1#-}" != "${1}" ]; then
	set -- "$PI_WEB_PATH" "$@"
elif [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && [ ! -x "${1}" ]; }; then
	set -- node "$@"
fi

exec "$@"
