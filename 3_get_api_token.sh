#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

revolut_env="${REVOLUT_ENV:-production}"
token_url_production="${TOKEN_URL_PRODUCTION:-https://b2b.revolut.com/api/1.0/auth/token}"
token_url_sandbox="${TOKEN_URL_SANDBOX:-}"

if [[ -n "${1:-}" ]]; then
  token_url="$1"
elif [[ "$revolut_env" == "production" ]]; then
  token_url="$token_url_production"
elif [[ "$revolut_env" == "sandbox" ]]; then
  token_url="$token_url_sandbox"
else
  echo "Invalid REVOLUT_ENV='$revolut_env'. Use 'production' or 'sandbox'."
  exit 1
fi

if [[ -z "$token_url" ]]; then
  echo "Missing token URL for REVOLUT_ENV='$revolut_env'. Set TOKEN_URL_PRODUCTION or TOKEN_URL_SANDBOX in .env."
  exit 1
fi

auth_code_env="${AUTH_CODE:-}"
client_assertion_env="${JWT_TOKEN_CLIENT_ASSERTION:-}"

auth_code="$auth_code_env"
client_assertion="$client_assertion_env"

if [[ -z "$auth_code" ]]; then
  echo "No auth code provided. Set AUTH_CODE in .env (or run ./2_get_code.sh)."
  exit 1
fi

if [[ -z "$client_assertion" ]]; then
  echo "Missing JWT_TOKEN_CLIENT_ASSERTION in .env. Run ./1_create_jwt.sh first."
  exit 1
fi

curl -sS "$token_url" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "grant_type=authorization_code" \
  --data "code=${auth_code}" \
  --data "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data "client_assertion=${client_assertion}" \
  > /tmp/revolut_token_response.json

response_body="$(tr -d '\r' < /tmp/revolut_token_response.json)"

if ! printf '%s' "$response_body" | jq -e . >/dev/null 2>&1; then
  echo "Token endpoint did not return valid JSON."
  echo "Raw response:"
  printf '%s\n' "$response_body"
  exit 1
fi

access_token="$(printf '%s' "$response_body" | jq -r '.access_token // empty')"
refresh_token="$(printf '%s' "$response_body" | jq -r '.refresh_token // empty')"

if [[ -z "$access_token" || -z "$refresh_token" ]]; then
  echo "Missing access_token or refresh_token in response."
  echo "Response:"
  printf '%s\n' "$response_body" | jq '.'
  exit 1
fi

api_base_url="$(printf '%s' "$token_url" | sed -E 's#^((https?://[^/]+)).*#\1#')"

echo
echo "API BASE URL"
echo "$api_base_url"
echo
echo "ACCESS_TOKEN"
echo "$access_token"
echo
echo "JWT"
echo "$client_assertion"
echo
echo "REFRESH_TOKEN"
echo "$refresh_token"
