#!/usr/bin/env bash
# Build an App Store IPA locally (macOS + Xcode required).
# Upload the .ipa with Transporter or: Xcode → Window → Organizer → Distribute App.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "→ flutter pub get"
flutter pub get

echo "→ pod install"
(cd ios && pod install)

echo "→ flutter build ipa (release)"
flutter build ipa --release

IPA_PATH="$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -n 1)"
if [[ -z "${IPA_PATH}" ]]; then
  echo "No IPA found under build/ios/ipa/"
  exit 1
fi

echo ""
echo "Done. IPA: ${IPA_PATH}"
echo "Upload with Apple Transporter or Xcode Organizer → Distribute App → App Store Connect."
