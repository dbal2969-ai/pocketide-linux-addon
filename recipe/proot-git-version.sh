#!/usr/bin/env sh
set -eu

if [ "${1:-}" != "describe" ]; then
    echo 'Unsupported PRoot version query.' >&2
    exit 1
fi
printf '%s\n' 'v5.1.107.96'
