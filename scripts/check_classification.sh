#!/usr/bin/env bash
# Static check: fail if a forbidden data-classification identifier
# appears in lib/ in a dangerous position.
#
# Rules:
#   1. No direct print/debugPrint in lib/ outside SecureLogger itself.
#   2. No forbidden identifier is interpolated into a log message or
#      used as a map key in a log call.
#   3. The SecureLogger denylist must exist and be non-empty.
#   4. No shared_preferences in lib/.
#
# Exit 0 on pass, 1 on any violation.

set -euo pipefail

cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail=0
report() {
  echo -e "${RED}FAIL${NC}: $1"
  fail=1
}
ok() {
  echo -e "${GREEN}OK${NC}: $1"
}

# Restricted and Confidential identifiers from DATA_CLASSIFICATION.md §2.
# Case-sensitive; extend when the classification doc changes.
FORBIDDEN='biometric_embedding|biometricEmbedding|db_key|dbKey|private_key|privateKey|session_token|sessionToken|face_embedding|faceEmbedding|jwt_secret|jwtSecret|latitude|longitude|gps|credential|password'

# --- Rule 1: no direct print/debugPrint, except in the logger itself ---

violations=$(grep -rnE '(^|[^a-zA-Z_])print\(|debugPrint\(' lib/ 2>/dev/null \
  | grep -v "^lib/core/logging/secure_logger.dart:" \
  | grep -vE "check-classification: allow" || true)
if [ -n "$violations" ]; then
  report "direct print/debugPrint in lib/ — use SecureLogger"
  echo "$violations"
else
  ok "no direct print/debugPrint in lib/ (SecureLogger itself is allowed)"
fi

# --- Rule 2: forbidden identifiers in dangerous positions ---
#
# Two positions are dangerous:
#   a. Interpolated variable:  '$latitude'  or  '${latitude}'
#   b. Map key:                'latitude': value
#
# A plain message string like 'keystore.db_key.generated' is NOT a
# violation: it names an event, not data.

interp_pattern="\\\$[a-zA-Z_]*(${FORBIDDEN})"
key_pattern="'(${FORBIDDEN})'[[:space:]]*:"

violations=$(grep -rnE "SecureLogger\.(i|w|e|event|d)\(" lib/ 2>/dev/null \
  | grep -vE "check-classification: allow" \
  | grep -E "${interp_pattern}|${key_pattern}" || true)
if [ -n "$violations" ]; then
  report "forbidden identifier interpolated or used as a map key in a log call"
  echo "$violations"
else
  ok "no forbidden identifiers in dangerous positions in log calls"
fi

# --- Rule 3: SecureLogger denylist is populated ---

if [ ! -f "lib/core/logging/secure_logger.dart" ]; then
  report "lib/core/logging/secure_logger.dart is missing"
else
  count=$(grep -cE "^\s*'" lib/core/logging/secure_logger.dart || true)
  if [ "$count" -lt 10 ]; then
    report "SecureLogger denylist has fewer than 10 entries — was it emptied?"
  else
    ok "SecureLogger denylist has $count entries"
  fi
fi

# --- Rule 4: no shared_preferences for app state ---

violations=$(grep -rn "shared_preferences" lib/ 2>/dev/null \
  | grep -vE "check-classification: allow" || true)
if [ -n "$violations" ]; then
  report "shared_preferences used in lib/ — use KeyStore or SQLCipher"
  echo "$violations"
else
  ok "no shared_preferences in lib/"
fi

# --- Summary ---

if [ "$fail" -eq 0 ]; then
  echo
  echo -e "${GREEN}classification check passed${NC}"
  exit 0
fi

echo
echo -e "${RED}classification check failed${NC}"
exit 1
