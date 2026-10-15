#!/usr/bin/env bash
# verify.sh - smoke test for chromium-binary-lightweight
#
# Usage:
#   ./verify.sh           # extracts zip, runs a headless dump against a data: URL,
#                         # confirms the Chromium binary launches and renders
#   ./verify.sh <zip>     # verify a specific zip instead of ./chromium-lambda.zip
#
# Designed to run on:
#   - Amazon Linux 2 (Lambda base image, public.ecr.aws/lambda/python:3.11)
#   - Ubuntu 22.04+
#   - macOS + Linux x86_64
#
# Exits 0 on success, non-zero on any failure. Safe to wire into CI.

set -euo pipefail

ZIP="${1:-chromium-lambda.zip}"
WORK="$(mktemp -d -t chromium-verify.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Verifying $ZIP"
if [ ! -f "$ZIP" ]; then
  echo "    FAIL: $ZIP not found. Run from the repo root or pass a path." >&2
  exit 2
fi

echo "==> Extracting to $WORK"
unzip -q "$ZIP" -d "$WORK"

BIN="$WORK/bin/chromium"
if [ ! -e "$BIN" ]; then
  echo "    FAIL: $BIN is missing after extract." >&2
  exit 3
fi
# Zip entries don't always preserve +x on Unix. The README's install steps
# already say `chmod +x bin/chromium`; do the same here so verify.sh is the
# only command a CI job needs to run.
chmod +x "$BIN"

# Probe library load by asking for the version. Suppress stderr noise; capture
# any crash signature from the exit code only.
echo "==> Probing Chromium version"
if ! LD_LIBRARY_PATH="$WORK/bin/lib:${LD_LIBRARY_PATH:-}" "$BIN" --version >/dev/null 2>&1; then
  # --version isn't a stable Chromium flag across all builds; fall back to
  # a real headless dump below, which is the actual smoke test.
  echo "    (no --version flag; continuing to headless smoke test)"
fi

# Real smoke test: headless dump-dom on a 1-line data: URL. We don't need
# network access; data: URLs work offline. Output must contain our marker.
echo "==> Headless smoke test (data: URL)"
OUT_FILE="$WORK/dump.html"
SMOKE_URL='data:text/html,<title>verify-smoke</title><h1>OK</h1>'

set +e
LD_LIBRARY_PATH="$WORK/bin/lib:${LD_LIBRARY_PATH:-}" \
  "$BIN" \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --single-process \
    --no-zygote \
    --dump-dom \
    "$SMOKE_URL" \
    >"$OUT_FILE" 2>"$WORK/stderr.log"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "    FAIL: chromium exited $RC" >&2
  echo "    --- stderr ---" >&2
  sed 's/^/    /' "$WORK/stderr.log" >&2 || true
  exit 4
fi

if ! grep -q 'verify-smoke' "$OUT_FILE"; then
  echo "    FAIL: dump-dom output missing expected marker." >&2
  echo "    --- output (first 200 bytes) ---" >&2
  head -c 200 "$OUT_FILE" >&2 || true
  echo >&2
  exit 5
fi

SIZE=$(wc -c <"$OUT_FILE")
echo "    OK: rendered $SIZE bytes, marker 'verify-smoke' found"

echo
echo "PASS - Chromium binary is functional on this host."
echo "  Build provenance (from zip mtimes):"
echo "    binary built: $(unzip -l "$ZIP" bin/chromium 2>/dev/null | awk 'NR==4 {print $2, $3}')"
echo "    zip packaged: $(unzip -l "$ZIP" 2>/dev/null | tail -2 | head -1 | awk '{print $2, $3}')"
