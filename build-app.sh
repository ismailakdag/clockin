#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
swift build -c release

APP_DIR="$PWD/dist/Clockin.app"
CONTENTS="$APP_DIR/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp ".build/release/Clockin" "$CONTENTS/MacOS/Clockin"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Uygulamanin "guncelleme var mi" diye sorabilmesi icin hangi commit'ten
# uretildigi pakete yazilir. Depo disinda derlenmisse bos gecilir.
BUILD_COMMIT="$(git rev-parse HEAD 2>/dev/null || print unknown)"
# Karsilastirma noktasi olarak HEAD degil, origin/main ile ortak ata yazilir.
# Yerel commitler tasiyan bir derlemede HEAD depoda bulunmaz ve karsilastirma
# 404 doner; ortak ata her zaman depoda vardir.
UPSTREAM_BASE="$(git merge-base HEAD origin/main 2>/dev/null || print "$BUILD_COMMIT")"
for pair in "ClockinBuildCommit:$BUILD_COMMIT" "ClockinUpstreamBase:$UPSTREAM_BASE"; do
  key="${pair%%:*}"; value="${pair#*:}"
  /usr/libexec/PlistBuddy -c "Add :$key string $value" "$CONTENTS/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :$key $value" "$CONTENTS/Info.plist"
done

# Guncelleme betigi depo klasorunun yaninda duruyorsa yolu da yazilir,
# boylece uygulama "Update now" ile onu calistirabilir.
for candidate in "$PWD/../Clockin Güncelle.command" "$PWD/update.command"; do
  if [[ -f "$candidate" ]]; then
    /usr/libexec/PlistBuddy -c "Add :ClockinUpdateScript string ${candidate:A}" "$CONTENTS/Info.plist" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Set :ClockinUpdateScript ${candidate:A}" "$CONTENTS/Info.plist"
    break
  fi
done
if [[ -d ".build/release/Clockin_Clockin.bundle" ]]; then
  cp -R ".build/release/Clockin_Clockin.bundle" "$CONTENTS/Resources/"
fi
cp "Resources/Clockin.icns" "$CONTENTS/Resources/Clockin.icns"
codesign --force --deep --sign - "$APP_DIR"

print "Built: $APP_DIR"
print "Open with: open '$APP_DIR'"
