#!/bin/bash
# Netlify build script for NGGC Flutter Web App
set -e

echo "=== Cloning Flutter SDK ==="
git clone https://github.com/flutter/flutter.git --depth 1 --branch 3.24.5 _flutter
export PATH="$PATH:`pwd`/_flutter/bin"

echo "=== Flutter version ==="
flutter --version

echo "=== Enabling web support ==="
flutter config --enable-web

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building web (release) ==="
flutter build web --release

echo "=== Build complete! ==="
ls -la build/web
