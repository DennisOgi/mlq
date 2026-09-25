#!/usr/bin/env bash
set -euo pipefail

if [ ! -x flutter/bin/flutter ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
fi

flutter/bin/flutter config --no-analytics
flutter/bin/flutter precache --web
flutter/bin/flutter pub get
