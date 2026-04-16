# Revolut API Auth Scripts

This repo is a minimal flow for getting a Revolut Business API access token.

## Prerequisites

- `bash`, `openssl`, `jq`, `python3`, `curl`
- A configured `.env` file in this folder

Quick start:

```bash
cp .env.example .env
```

## Environment Configuration

All runtime values are managed in `.env`.

Key variables:

- Certificate:
  - `PRIVATE_KEY_FILE`, `PUBLIC_CERT_FILE`, `PFX_FILE`, `BASE64_FILE`
  - `CERT_PASSWORD` (leave empty to get interactive password prompt)
- JWT:
  - `JWT_KEY_FILE`, `JWT_ALG`, `JWT_TYP`, `JWT_ISS`, `JWT_SUB`, `JWT_AUD`
  - `JWT_EXP_DAYS` (preferred)
  - `JWT_TOKEN_CLIENT_ASSERTION` (auto-updated by script)
- OAuth:
  - `AUTH_CODE` (auto-updated by script)
  - `REVOLUT_ENV=production|sandbox`
  - `AUTHORIZE_URL_PRODUCTION`, `AUTHORIZE_URL_SANDBOX`
  - `TOKEN_URL_PRODUCTION`, `TOKEN_URL_SANDBOX`

## Sandbox and Production

- Production defaults:
  - `AUTHORIZE_URL_PRODUCTION=https://business.revolut.com/app-confirm`
  - `TOKEN_URL_PRODUCTION=https://b2b.revolut.com/api/1.0/auth/token`
- Sandbox (set these explicitly):
  - `AUTHORIZE_URL_SANDBOX=https://sandbox-business.revolut.com/app-confirm`
  - `TOKEN_URL_SANDBOX=https://sandbox-b2b.revolut.com/api/1.0/auth/token`

Switch environment via:

```bash
REVOLUT_ENV=sandbox
```

## Script Flow

1. Generate certificate files into `cert/`:

```bash
./0_create_certificate.sh
```

After generating, script output also shows:
- where to upload certificate in Revolut Business app
- OAuth redirect URI to paste
- X.509 certificate text to copy
- reminder to copy Client ID into `JWT_SUB` in `.env`

2. Open Revolut consent page and capture `AUTH_CODE` into `.env`:

```bash
./2_get_code.sh
```

3. Build JWT client assertion and store it in `.env` as `JWT_TOKEN_CLIENT_ASSERTION`:

```bash
./1_create_jwt.sh
```

4. Exchange authorization code for access token:

```bash
./3_get_api_token.sh
```

Output format is copy-friendly and prints:
- `API BASE URL`
- `ACCESS_TOKEN`
- `JWT`
- `REFRESH_TOKEN`

Official Revolut step reference:

- [4. Exchange authorization code for access token](https://developer.revolut.com/docs/guides/manage-accounts/get-started/make-your-first-api-request#4-exchange-authorization-code-for-access-token)
