#!/usr/bin/env bash
set -euo pipefail

### — Paramètres à personnaliser —
APPLE_ID="dbili.mt@gmail.com"                       # ton Apple ID
APP_SPEC_PWD="mkqc-fnaa-weei-vklj"                  # app-specific password (16 chars)
TEAM_ID_DEV_ID="6GXJLNLZ94"                         # Team ID
SIGN_HASH="882A438A37545346CB92745DE7C3342ADAD62AD0"  # SHA-1 Developer ID Application choisi
APP="build/macos/Build/Products/Release/cse_kch.app"  # nom exact généré par Flutter
ZIP="cse_kch.zip"
PROFILE_NAME="notary-cse"
KEYCHAIN_DB="$HOME/Library/Keychains/login.keychain-db"
### ————————————————

echo "==> Build si besoin…"
flutter pub get >/dev/null
if [ ! -d "$APP" ]; then
  flutter build macos --release
fi

echo "==> Signature (hardened runtime)…"
codesign --force --deep --options runtime --timestamp \
  --keychain "$KEYCHAIN_DB" \
  --sign "$SIGN_HASH" "$APP"

echo "==> Vérif codesign…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Archive ZIP…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Enregistrement profil notarytool (si besoin)…"
xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID_DEV_ID" \
  --password "$APP_SPEC_PWD" >/dev/null 2>&1 || true

echo "==> Soumission notarisation (attente)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE_NAME" --wait

echo "==> Staple (agrafer le ticket)…"
xcrun stapler staple "$APP"

echo "==> Gatekeeper check…"
spctl -a -vv "$APP" || true

echo "✅ Terminé. Distribue : build/macos/Build/Products/Release/cse_kch.app"
