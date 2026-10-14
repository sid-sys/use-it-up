#!/bin/sh
# Xcode Cloud runs this after it clones the repo. It installs Flutter and the iOS pods,
# because the Flutter files that Xcode needs are not stored in git.
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b 3.47.1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter precache --ios
flutter pub get

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install
