#!/bin/bash
echo "Cleaning Flutter project..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Running Flutter doctor to verify setup..."
flutter doctor -v

echo "Running the app..."
flutter run
