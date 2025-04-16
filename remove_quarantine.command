#!/bin/bash

APP_PATH="/Applications/FrameTool.app"

if [ -d "$APP_PATH" ]; then
	echo "🧼 Removing quarantine attributes from: $APP_PATH"
	xattr -rd com.apple.quarantine "$APP_PATH"
	echo "✅ Done!"
else
	echo "❌ Could not find FrameTool.app in /Applications/"
	echo "Please move the app there first."
	exit 1
fi
