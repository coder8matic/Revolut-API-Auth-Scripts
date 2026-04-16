#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

client_id="${JWT_SUB:-}"
jwt_iss="${JWT_ISS:-}"
redirect_uri="https://${jwt_iss}/"
revolut_env="${REVOLUT_ENV:-production}"
authorize_url_production="${AUTHORIZE_URL_PRODUCTION:-https://business.revolut.com/app-confirm}"
authorize_url_sandbox="${AUTHORIZE_URL_SANDBOX:-}"

if [[ -z "$client_id" || -z "$jwt_iss" ]]; then
  echo "Missing OAuth data. Set JWT_SUB and JWT_ISS in .env."
  exit 1
fi

encoded_redirect_uri="$(
  python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$redirect_uri"
)"

if [[ "$revolut_env" == "production" ]]; then
  authorize_url_base="$authorize_url_production"
elif [[ "$revolut_env" == "sandbox" ]]; then
  authorize_url_base="$authorize_url_sandbox"
else
  echo "Invalid REVOLUT_ENV='$revolut_env'. Use 'production' or 'sandbox'."
  exit 1
fi

if [[ -z "$authorize_url_base" ]]; then
  echo "Missing authorize URL for REVOLUT_ENV='$revolut_env'. Set AUTHORIZE_URL_PRODUCTION or AUTHORIZE_URL_SANDBOX in .env."
  exit 1
fi

authorize_url="${authorize_url_base}?client_id=${client_id}&redirect_uri=${encoded_redirect_uri}&response_type=code"

echo "Opening Revolut authorize URL in browser..."
echo "$authorize_url"
if command -v open >/dev/null 2>&1; then
  open "$authorize_url" >/dev/null 2>&1 || true
fi

echo
echo "After approving in Revolut app, paste the FULL redirect URL here:"
read -r redirect_result_url

auth_code="$(
  python3 -c 'import sys, urllib.parse; u=sys.argv[1]; q=urllib.parse.urlparse(u).query; print(urllib.parse.parse_qs(q).get("code", [""])[0])' "$redirect_result_url"
)"

if [[ -z "$auth_code" ]]; then
  echo "Could not extract 'code' from the provided URL."
  exit 1
fi

if [[ -f .env ]]; then
  AUTH_CODE_NEW="$auth_code" python3 - <<'PY'
from pathlib import Path
import os
path = Path(".env")
code = os.environ["AUTH_CODE_NEW"]
lines = path.read_text().splitlines()
updated = []
replaced = False
for line in lines:
    if line.startswith("AUTH_CODE="):
        if not replaced:
            updated.append(f"AUTH_CODE={code}")
            replaced = True
        # Drop duplicate definitions if present.
    else:
        updated.append(line)
if not replaced:
    updated.append(f"AUTH_CODE={code}")
path.write_text("\n".join(updated) + "\n")
PY
  set -a
  source .env
  set +a
  echo "Updated AUTH_CODE in .env"
  echo "Reloaded .env in this script process."
  echo "If needed in current shell too, run: set -a; source .env; set +a"
fi