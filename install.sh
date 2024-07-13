#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Print commands and their arguments as they are executed.
set -x

REPO="https://github.com/mr-pennyworth/alfred-extra-pane"
APP_NAME="AlfredExtraPane.app"
LATEST_RELEASE_URL="$REPO/releases/latest/download/$APP_NAME.zip"
TEMP_DIR="/tmp/alfred-extra-pane"
APP_ZIP="$TEMP_DIR/$APP_NAME.zip"
APP_PATH="/Applications/$APP_NAME"


mkdir -p $TEMP_DIR

echo "Downloading the latest release..."
curl -L $LATEST_RELEASE_URL -o $APP_ZIP

echo "Extracting the app..."
unzip -q $APP_ZIP -d $TEMP_DIR

echo "Moving the app to /Applications..."
mv "$TEMP_DIR/$APP_NAME" /Applications/

echo "Checking and removing the quarantine attribute if it exists..."
if xattr -p com.apple.quarantine $APP_PATH > /dev/null 2>&1; then
  xattr -d com.apple.quarantine $APP_PATH
fi

echo "Cleaning up..."
rm -rf $TEMP_DIR

echo "Installation complete."
open /Applications
