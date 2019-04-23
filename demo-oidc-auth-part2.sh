#!/usr/bin/env bash

export VAULT_TOKEN=devroot
export VAULT_ADDR=http://127.0.0.1:8200

cat - > /tmp/admpolicy.hcl <<EOF
path "/secret/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}
path "/identity/*" {
	capabilities = ["read", "list"]
}
path "/sys/policies/*" {
	capabilities = ["read", "list"]
}
EOF

vault policy write adm /tmp/admpolicy.hcl

vault write auth/oidc/role/demo groups_claim="https://example.com/roles"

gid=$(
  vault write -format=json identity/group \
    name="auth0-admin" \
    policies="adm" \
    type="external" \
    metadata=organization="Auth0 Users" |
      jq -r .data.id)

vault write identity/group-alias name="admin" \
    mount_accessor=$(vault auth list -format=json  | jq -r '."oidc/".accessor') \
    canonical_id="${gid}"
