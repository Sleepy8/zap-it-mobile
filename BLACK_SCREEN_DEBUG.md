# Black Screen Debug Guide

## Problem Description
The app is showing a black screen in both the iOS simulator and Codemagic preview.

## Root Causes Identified
1. **Firebase Initialization Issues**: The app was skipping Firebase on iOS, which could cause initialization problems
2. **Theme Configuration**: Missing fallback colors and incomplete theme setup
3. **Error Handling**: No proper fallbacks when services fail to initialize
4. **Platform-specific Issues**: iOS simulator might have different behavior

## Solutions Implemented

### 1. Fixed main.dart
- Improved Firebase initialization with proper error handling
- Added loading states and better error management
- Enhanced MediaQuery configuration to prevent content hiding
- Added proper fallbacks for failed service initialization

### 2. Enhanced theme.dart
- Added comprehensive color scheme properties
- Included fallback colors for all components
- Enhanced Material 3 compatibility
- Added missing theme properties for better platform support

### 3. Created Test Screen
- Simple screen to verify basic Flutter rendering
- Tests colors, text, buttons, and layout
- Helps isolate rendering issues from business logic

### 4. Created Debug Version
- `main_debug.dart` that bypasses Firebase completely
- Goes directly to test screen for debugging
- Useful for isolating Firebase-related issues

## Debugging Steps

### Step 1: Test with Debug Version
1. Change your `main.dart` to `main_debug.dart` in your IDE
2. Run the app - it should show the test screen immediately
3. If this works, the issue is with Firebase initialization

### Step 2: Check Console Logs
Look for these messages in the console:
- "App starting in DEBUG mode - NO FIREBASE"
- "Firebase initialized successfully" or "Firebase initialization failed"
- Any error messages related to services

### Step 3: Test Individual Components
1. Navigate to `/test` route in the main app
2. Check if the test screen renders correctly
3. Verify colors, text, and buttons are visible

### Step 4: Check Firebase Configuration
1. Verify `GoogleService-Info.plist` exists for iOS
2. Check Firebase project configuration
3. Ensure all required Firebase services are enabled

## Quick Fixes to Try

### Option 1: Use Debug Version
```bash
# Temporarily rename files to test
mv lib/main.dart lib/main_prod.dart
mv lib/main_debug.dart lib/main.dart
```

### Option 2: Force Test Screen
Add this route to your main.dart and navigate to it:
```dart
'/test': (context) => const TestScreen(),
```

### Option 3: Check Dependencies
```bash
flutter clean
flutter pub get
flutter run
```

## Common Issues and Solutions

### Issue: Still Black Screen
- Check if the test screen renders
- Verify theme colors are not all black
- Check console for error messages

### Issue: Firebase Errors
- Verify Firebase configuration files
- Check internet connectivity
- Ensure Firebase project is properly set up

### Issue: iOS Simulator Specific
- Try different iOS simulator versions
- Check iOS deployment target
- Verify CocoaPods installation

## Next Steps
1. Test with the debug version first
2. If debug version works, gradually add back Firebase features
3. Check Codemagic build logs for specific errors
4. Verify all platform-specific configurations

## Files Modified
- `lib/main.dart` - Enhanced error handling and initialization
- `lib/theme.dart` - Improved theme configuration
- `lib/screens/test_screen.dart` - New test screen
- `lib/main_debug.dart` - Debug version without Firebase

## Testing Commands
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run with debug version
flutter run --target=lib/main_debug.dart

# Run normal version
flutter run
```
