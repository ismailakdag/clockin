#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${1:?Pass a prepared release directory}"
RELEASE_DIR="${1:A}"
PLIST="$PWD/dist/Clockin.app/Contents/Info.plist"
WORK="$(mktemp -d "$PWD/dist/verification-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
swiftc scripts/verify-release.swift -o "$WORK/verify"
"$WORK/verify" "$RELEASE_DIR/appcast.xml" "$PLIST"
ditto "$RELEASE_DIR" "$WORK/tampered"
# A feed edit must fail before its contents are trusted.
/usr/bin/python3 - "$WORK/tampered/appcast.xml" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
b = p.read_bytes()
assert b"<title>" in b
p.write_bytes(b.replace(b"<title>", b"<title>X", 1))
PY
if "$WORK/verify" "$WORK/tampered/appcast.xml" "$PLIST" > "$WORK/result.log" 2>&1; then
    print -u2 'FAIL: modified feed was accepted'; exit 1
fi
rg -q 'Feed length mismatch|Feed signature does not match' "$WORK/result.log"
print 'PASS: modified feed rejected'
cp "$RELEASE_DIR/appcast.xml" "$WORK/tampered/appcast.xml"
# Change a byte while preserving the length so this tests the signature too.
/usr/bin/python3 - "$WORK/tampered" <<'PY'
import pathlib, sys
p = next(pathlib.Path(sys.argv[1]).glob("*.dmg"))
b = bytearray(p.read_bytes())
b[len(b) // 2] ^= 1
p.write_bytes(b)
PY
if "$WORK/verify" "$WORK/tampered/appcast.xml" "$PLIST" > "$WORK/result.log" 2>&1; then
    print -u2 'FAIL: modified archive was accepted'; exit 1
fi
rg -q 'Invalid archive signature' "$WORK/result.log"
print 'PASS: modified archive rejected'
