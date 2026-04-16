#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

key_file="${1:-${JWT_KEY_FILE:-cert/rev_privatecert.pem}}"
cert_password="${CERT_PASSWORD:-}"

jwt_alg="${JWT_ALG:-RS256}"
jwt_typ="${JWT_TYP:-JWT}"
jwt_iss="${JWT_ISS:-}"
jwt_sub="${JWT_SUB:-}"
jwt_aud="${JWT_AUD:-}"
jwt_exp="${JWT_EXP:-}"
jwt_exp_days="${JWT_EXP_DAYS:-}"

b64url() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

if [[ -n "$jwt_exp_days" ]]; then
  if ! [[ "$jwt_exp_days" =~ ^[0-9]+$ ]]; then
    echo "JWT_EXP_DAYS must be a non-negative integer."
    exit 1
  fi
  now_epoch="$(date +%s)"
  jwt_exp="$((now_epoch + (jwt_exp_days * 86400)))"
fi

if [[ -z "$jwt_iss" || -z "$jwt_sub" || -z "$jwt_aud" || -z "$jwt_exp" ]]; then
  echo "Missing required JWT payload env vars (JWT_ISS, JWT_SUB, JWT_AUD, and JWT_EXP or JWT_EXP_DAYS)."
  exit 1
fi

header_json="$(jq -cn --arg alg "$jwt_alg" --arg typ "$jwt_typ" '{alg: $alg, typ: $typ}')"
payload_json="$(
  jq -cn \
    --arg iss "$jwt_iss" \
    --arg sub "$jwt_sub" \
    --arg aud "$jwt_aud" \
    --argjson exp "$jwt_exp" \
    '{iss: $iss, sub: $sub, aud: $aud, exp: $exp}'
)"

header_b64=$(printf '%s' "$header_json" | b64url)
payload_b64=$(printf '%s' "$payload_json" | b64url)
signing_input="${header_b64}.${payload_b64}"

if [[ -n "$cert_password" ]]; then
  signature_b64=$(
    printf '%s' "$signing_input" \
      | openssl dgst -sha256 -sign "$key_file" -passin "pass:${cert_password}" \
      | b64url
  )
else
  signature_b64=$(
    printf '%s' "$signing_input" \
      | openssl dgst -sha256 -sign "$key_file" \
      | b64url
  )
fi

jwt="${signing_input}.${signature_b64}"

if [[ -f .env ]]; then
  JWT_TOKEN_CLIENT_ASSERTION_NEW="$jwt" python3 - <<'PY'
from pathlib import Path
import os

path = Path(".env")
jwt = os.environ["JWT_TOKEN_CLIENT_ASSERTION_NEW"]
lines = path.read_text().splitlines()
updated = []
replaced = False
for line in lines:
    if line.startswith("JWT_TOKEN_CLIENT_ASSERTION="):
        if not replaced:
            updated.append(f"JWT_TOKEN_CLIENT_ASSERTION={jwt}")
            replaced = True
        # Drop duplicate definitions if present.
    else:
        updated.append(line)
if not replaced:
    updated.append(f"JWT_TOKEN_CLIENT_ASSERTION={jwt}")
path.write_text("\n".join(updated) + "\n")
PY
  set -a
  source .env
  set +a
  echo "Updated JWT_TOKEN_CLIENT_ASSERTION in .env"
  echo "Reloaded .env in this script process."
  echo "If needed in current shell too, run: set -a; source .env; set +a"
else
  echo "Missing .env. Create it first."
  exit 1
fi