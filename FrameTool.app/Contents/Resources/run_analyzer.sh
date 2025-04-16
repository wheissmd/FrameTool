#!/bin/bash

APP_RESOURCES="$(dirname "$0")"
PYTHON_BIN="$APP_RESOURCES/venv/bin/python3"
PYTHON_SCRIPT="$APP_RESOURCES/analyze_frametime.py"

if [ -z "$1" ]; then
	echo "⚠️ No video file provided."
	exit 1
fi

"$PYTHON_BIN" "$PYTHON_SCRIPT" "$1"
