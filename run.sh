#!/bin/bash
echo "Cleaning Flutter project..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Fixing Android structures..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  powershell -ExecutionPolicy Bypass -File ./fix_plugins.ps1
  powershell -ExecutionPolicy Bypass -File ./fix_android_package.ps1
fi

echo "Running Flutter doctor to verify setup..."
flutter doctor -v

echo "Running the app..."
flutter run --verbose
