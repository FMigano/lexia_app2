# Lexia App

A Reddit-like community platform for parents and professionals using Flutter.

## Setup Instructions

1. **Install dependencies**:
   ```
   flutter pub get
   ```

2. **Firebase Setup**:
   - Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Install FlutterFire CLI:
     ```
     dart pub global activate flutterfire_cli
     ```
   - Configure Firebase for your project:
     ```
     flutterfire configure
     ```
   - This will update the firebase_options.dart file with your project details

3. **Create required directories**:
   Make sure the assets/images directory exists:
   ```
   mkdir -p assets/images
   ```

4. **Run the app**:
   ```
   flutter run
   ```

## Features

- Authentication system with Parent/Professional roles
- Forum-style homepage for community posts
- Professional directory with search and filters
- Direct messaging system between users
- User profiles with role-specific information
