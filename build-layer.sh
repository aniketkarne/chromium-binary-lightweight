#!/usr/bin/env bash
# Assemble an AWS Lambda layer zip from chromium-lambda.zip.
#
# Why this exists: the manual layer steps (unzip -> cp -> zip) have two traps.
# The zip stores bin/chromium WITHOUT the executable bit, so a layer built
# straight from the extract fails at runtime with "Permission denied". And the
# zip carries macOS junk (__MACOSX/, .DS_Store) that rides along into the layer.
# This script strips the junk, sets the exec bit, and zips bin/ at the layer
# root so the archive extracts to /opt/bin/... as Lambda expects.
#
# Usage:  ./build-layer.sh [source-zip] [output-zip]
#         defaults: chromium-lambda.zip -> chromium-layer.zip
#
# Requires: unzip, zip. Works on macOS stock bash 3.2 and Linux bash 5.x.

set -euo pipefail

SRC="${1:-chromium-lambda.zip}"
OUT="${2:-chromium-layer.zip}"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ -f "$SRC" ] || fail "source zip not found: $SRC"
command -v unzip >/dev/null 2>&1 || fail "unzip not found in PATH"
command -v zip >/dev/null 2>&1 || fail "zip not found in PATH"

STAGING="$(mktemp -d -t chromium-layer.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> Extracting $SRC"
unzip -q "$SRC" -d "$STAGING"

echo "==> Stripping macOS junk (__MACOSX/, .DS_Store, ._*)"
rm -rf "$STAGING/__MACOSX"
find "$STAGING" \( -name '.DS_Store' -o -name '._*' \) -delete

# Every entry the layer needs. Missing one means the source zip is not the
# artifact this repo ships.
required="
bin/chromium
bin/pyppeteer-install
bin/tqdm
bin/lib/libexpat.so.1
bin/lib/libnss3.so
bin/lib/libnssutil3.so
bin/lib/libsoftokn3.so
bin/lib/libsqlite3.so.0
bin/lib/libuuid.so.1
"
for entry in $required; do
    [ -e "$STAGING/$entry" ] || fail "missing from source zip: $entry"
done

echo "==> Checking binary type"
if command -v file >/dev/null 2>&1; then
    desc="$(file -b "$STAGING/bin/chromium")"
    case "$desc" in
        *"ELF 64-bit"*"x86-64"*) echo "    $desc" ;;
        *) fail "bin/chromium is not a Linux x86_64 ELF binary: $desc" ;;
    esac
else
    echo "    (file(1) not available, skipping)"
fi

# The zip stores no executable bit. Without this the layer's chromium cannot
# be launched at all.
echo "==> Setting executable bits"
chmod 755 "$STAGING/bin/chromium" "$STAGING/bin/pyppeteer-install" "$STAGING/bin/tqdm"

echo "==> Creating $OUT (bin/ at layer root -> extracts to /opt/bin/)"
rm -f "$OUT"
(cd "$STAGING" && zip -qrX "$OLDPWD/$OUT" bin)

echo "==> Verifying $OUT"
# Capture the listing first: piping zipinfo into grep -q is a SIGPIPE race —
# grep exits on the first match and pipefail counts zipinfo's death as failure.
listing="$(zipinfo -1 "$OUT")"
missing=0
for entry in $required; do
    if ! grep -qx "$entry" <<< "$listing"; then
        echo "    MISSING from layer zip: $entry" >&2
        missing=1
    fi
done
[ "$missing" -eq 0 ] || fail "layer zip is incomplete"
if grep -qE '^__MACOSX/|\.DS_Store$' <<< "$listing"; then
    fail "layer zip contains macOS junk"
fi
perms="$(zipinfo -l "$OUT" 'bin/chromium' | awk '{print $1}')"
case "$perms" in
    -rwx*) echo "    bin/chromium stored executable ($perms)" ;;
    *) fail "bin/chromium not stored executable in layer zip (perms: $perms)" ;;
esac

echo ""
echo "Layer ready:"
echo "  file:   $OUT"
echo "  size:   $(wc -c < "$OUT" | tr -d ' ') bytes"
if command -v sha256sum >/dev/null 2>&1; then
    echo "  sha256: $(sha256sum "$OUT" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    echo "  sha256: $(shasum -a 256 "$OUT" | awk '{print $1}')"
fi
echo "  entries:"
zipinfo -1 "$OUT" | sed 's/^/    /'
echo ""
echo "Publish with:  aws lambda publish-layer-version --layer-name chromium --zip-file fileb://$OUT"
echo "Attach with:   --layers <layer-arn> and set LD_LIBRARY_PATH=/opt/bin/lib"
