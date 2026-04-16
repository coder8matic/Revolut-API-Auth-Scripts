#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

private_key_file="${1:-${PRIVATE_KEY_FILE:-cert/rev_privatecert.pem}}"
public_cert_file="${2:-${PUBLIC_CERT_FILE:-cert/rev_publiccert.cer}}"
common_name="${3:-${COMMON_NAME:-revolut-client}}"
days="${4:-${CERT_DAYS:-1825}}"
country="${5:-${CERT_COUNTRY:-SI}}"
state="${6:-${CERT_STATE:-Slovenia}}"
locality="${7:-${CERT_LOCALITY:-Ljubljana}}"
organization="${8:-${CERT_ORGANIZATION:-SuperPower d.o.o.}}"
org_unit="${9:-${CERT_ORG_UNIT:-IT}}"
email="${10:-${CERT_EMAIL:-it@suncontract.org}}"
pfx_file="${11:-${PFX_FILE:-cert/revolut.pfx}}"
base64_file="${12:-${BASE64_FILE:-cert/revolut.base64}}"
cert_password="${13:-${CERT_PASSWORD:-}}"
jwt_iss="${JWT_ISS:-}"
oauth_redirect_uri="${OAUTH_REDIRECT_URI:-}"

if [[ -z "$oauth_redirect_uri" && -n "$jwt_iss" ]]; then
  oauth_redirect_uri="https://${jwt_iss}/"
fi

subject="/C=${country}/ST=${state}/L=${locality}/O=${organization}/OU=${org_unit}/CN=${common_name}/emailAddress=${email}"

mkdir -p "$(dirname "$private_key_file")"
mkdir -p "$(dirname "$public_cert_file")"
mkdir -p "$(dirname "$pfx_file")"
mkdir -p "$(dirname "$base64_file")"

if [[ -n "$cert_password" ]]; then
  openssl genrsa -aes256 -passout "pass:${cert_password}" -out "$private_key_file" 2048
else
  openssl genrsa -aes256 -out "$private_key_file" 2048
fi

if [[ -n "$cert_password" ]]; then
  openssl req -new -x509 \
    -key "$private_key_file" \
    -passin "pass:${cert_password}" \
    -out "$public_cert_file" \
    -days "$days" \
    -subj "$subject"
else
  openssl req -new -x509 \
    -key "$private_key_file" \
    -out "$public_cert_file" \
    -days "$days" \
    -subj "$subject"
fi

echo "Created private key: $private_key_file"
echo "Created public certificate: $public_cert_file"

# Export certificate and private key to a PFX bundle.
if [[ -n "$cert_password" ]]; then
  openssl pkcs12 \
    -inkey "$private_key_file" \
    -passin "pass:${cert_password}" \
    -in "$public_cert_file" \
    -export \
    -passout "pass:${cert_password}" \
    -out "$pfx_file"
else
  openssl pkcs12 -inkey "$private_key_file" -in "$public_cert_file" -export -out "$pfx_file"
fi
# Create a base64-encoded version of the PFX for easier transport.
openssl base64 -in "$pfx_file" -out "$base64_file"

echo "Created PFX file: $pfx_file"
echo "Created base64 encoded PFX file: $base64_file"

cert_title_suggestion="${CERT_TITLE:-${common_name}-$(date +%Y%m%d)}"

echo
echo "========== Revolut Business App Setup =========="
echo "1) Open Revolut Business App -> ⚙️  settings -> API section -> API certificates -> Add new"
echo "2) Certificate title:"
echo "     <name your certificate>"
echo "3) OAuth redirect URI (copy/paste):"
if [[ -n "$oauth_redirect_uri" ]]; then
  echo "   ${oauth_redirect_uri}"
else
  echo "   Not set. Define JWT_ISS in .env (or OAUTH_REDIRECT_URI) and rerun."
fi
echo
echo "4) X.509 public certificate (copy/paste-ready):"
awk '1' "$public_cert_file"
echo
echo "5) Copy Client ID from Revolut app into .env:"
echo "   JWT_SUB=<your_client_id>"
echo "==============================================="