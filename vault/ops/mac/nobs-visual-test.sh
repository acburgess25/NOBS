#!/usr/bin/env bash
# NOBS iOS Application Simulator Deployment & Visual Testing Pipeline
# Boots the iPhone 17 simulator, installs the compiled build, and launches it.

DEVICE_ID="A734A45F-4135-4209-B764-5F6B2AF8409D" # iPhone 17
BUNDLE_ID="com.nobsdash.nobs"
APP_PATH="/Users/alexburgess/Library/Developer/Xcode/DerivedData/NOBS-deuyzmvviqprgrbrtdiuexxnoidv/Build/Products/Debug-iphonesimulator/NOBS.app"

echo "================ SIMULATOR BOOTSTRAPPING ================"

# 1. Open the macOS Simulator Application
echo "  -> Opening Simulator.app..."
open -a Simulator

# 2. Boot the iPhone 17 Device if not already booted
echo "  -> Booting iPhone 17 Simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID"

# 3. Verify Compiled Build Path
if [ ! -d "$APP_PATH" ]; then
  echo "  ❌ ERROR: Compiled app not found at:"
  echo "     $APP_PATH"
  echo "     Please run xcodebuild first or verify DerivedData compile targets."
  exit 1
fi
echo "  ✅ Located compiled app binary."

# 4. Install the App onto the Simulator
echo "  -> Installing NOBS app onto Simulator..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
echo "  ✅ App installed successfully!"

# 5. Launch the App
echo "  -> Launching $BUNDLE_ID inside Simulator..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
echo "  ✅ Application launched on screen!"

echo "================ READY FOR LOCAL AI TESTING ================"
echo "The NOBS iOS App is now open and active on your screen!"
echo ""
echo "To let your local OpenClaw agent test it autonomously:"
echo "1. Ensure OpenClaw is running."
echo "2. Open your local dashboard (http://127.0.0.1:18789/) or use Claw CLI."
echo "3. Prompt your agent:"
echo "   \"Use the peekaboo skill to inspect the Simulator app screen. Click through the onboarding Views (enter name, bio, interests), verify that it saves correctly without crashing, and write a summary of what does not work and how we can improve it.\""
echo ""
echo "============================================================"
