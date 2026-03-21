#!/bin/bash

# Exit on error
set -e

echo "Building obfuscated AAB for Release..."

# Run flutter build with obfuscation and save debug symbols
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols

echo ""
echo "✅ Build complete!"
echo "📦 AAB file: build/app/outputs/bundle/release/app-release.aab"
echo "🛠️ Debug symbols: build/app/outputs/symbols"
