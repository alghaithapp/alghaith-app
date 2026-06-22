#!/bin/bash
# Firebase FCM Setup — Al-Ghaith App
# ======================================
# Instructions:
# 1. Create a Firebase project at https://console.firebase.google.com
# 2. Add Android app with package: com.alghaith.app
# 3. Add iOS app with bundle: com.alghaith.app
# 4. Download google-services.json and GoogleService-Info.plist
# 5. Run this script from the project root:
#
#    bash scripts/setup_firebase.sh
#
# ======================================

set -e

echo "📱 Al-Ghaith Firebase Setup"
echo "==========================="

# Android
if [ -f "android/app/google-services.json" ]; then
    echo "✅ android/app/google-services.json found"
else
    echo "❌ android/app/google-services.json missing"
    echo "   → Download from Firebase Console → Android app → google-services.json"
    echo "   → Place in android/app/google-services.json"
    exit 1
fi

# iOS
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ ios/Runner/GoogleService-Info.plist found"
else
    echo "❌ ios/Runner/GoogleService-Info.plist missing"
    echo "   → Download from Firebase Console → iOS app → GoogleService-Info.plist"
    echo "   → Place in ios/Runner/GoogleService-Info.plist"
    exit 1
fi

# Firebase service account (backend)
if [ -n "$FIREBASE_SERVICE_ACCOUNT_JSON" ]; then
    echo "✅ FIREBASE_SERVICE_ACCOUNT_JSON env var set"
else
    echo "⚠️  FIREBASE_SERVICE_ACCOUNT_JSON env var not set"
    echo "   → Firebase Console → Project Settings → Service accounts"
    echo "   → Generate new private key → copy JSON to Railway env"
fi

# Railway deployment
echo ""
echo "🚂 Railway deployment (optional, run from backend/):"
echo "   railway variables set FIREBASE_SERVICE_ACCOUNT_JSON='<paste-json-here>'"
echo ""
echo "   Or use the helper script on Windows:"
echo "   .\\scripts\\configure_fcm_railway.ps1"
echo ""
echo "   After setting the variable, redeploy:"
echo "   railway up"
echo "   Or check: railway variables list | grep FIREBASE"

# flutterfire configure
echo ""
echo "🚀 Running flutterfire configure..."
if command -v flutterfire &> /dev/null; then
    flutterfire configure --project=YOUR_PROJECT_ID --yes
    echo "✅ firebase_options.dart generated"
else
    echo "⚠️  flutterfire CLI not found. Installing..."
    dart pub global activate flutterfire_cli
    flutterfire configure --project=YOUR_PROJECT_ID --yes
fi

# Backend push test
echo ""
echo "🧪 Testing backend push..."
node backend/scripts/send_test_push.js 2>/dev/null && echo "✅ Push test sent" || echo "⚠️  Push test skipped (needs FIREBASE_SERVICE_ACCOUNT_JSON)"

echo ""
echo "🎉 Firebase setup complete!"
echo "   - Run 'flutter build apk' or 'flutter build ios' to rebuild"
echo "   - Or push to Codemagic for CI build"
