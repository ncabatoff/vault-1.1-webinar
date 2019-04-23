#!/usr/bin/env bash

# Assumes jq and vault 1.1+ is in $PATH.
# Kills any running vault server.

kill $(ps ax |grep 'vault server' |awk '{print $1}') 2>/dev/null
set -e
source .env

sleep 1
vault server -dev -dev-root-token-id=devroot -log-level=debug > /tmp/vault.log 2>&1 &
sleep 1
export VAULT_TOKEN=devroot
export VAULT_ADDR=http://127.0.0.1:8200

cat - > /tmp/minpolicy.hcl <<EOF
path "/identity/*" {
	capabilities = ["read", "list"]
}
EOF
vault policy write min /tmp/minpolicy.hcl

vault auth enable oidc

vault write auth/oidc/config \
    oidc_discovery_url="https://$AUTH0_DOMAIN/" \
    oidc_client_id="$AUTH0_CLIENT_ID" \
    oidc_client_secret="$AUTH0_CLIENT_SECRET" \
    default_role="demo"

vault write auth/oidc/role/demo \
    bound_audiences="$AUTH0_CLIENT_ID" \
    allowed_redirect_uris="http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    user_claim="sub" \
    policies=min


