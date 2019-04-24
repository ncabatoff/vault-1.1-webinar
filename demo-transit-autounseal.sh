#!/usr/bin/env bash

set -e

tmpdir=`mktemp -d /tmp/vaultXXXXXX`

function start_primary() {
    echo "* start_primary"

    mkdir -p ${tmpdir}/vault-pri-data
    cat - > ${tmpdir}/vault-pri.hcl <<EOF
pid_file = "${tmpdir}/pri_pid_file"

listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = 1
}

storage "file" {
    path = "${tmpdir}/vault-pri-data"
}
EOF

    vault server -config ${tmpdir}/vault-pri.hcl > ${tmpdir}/vault-pri.log 2>&1 &
    sleep 1

    export VAULT_ADDR=http://localhost:8200
    initoutput=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
    vault operator unseal $(echo "$initoutput" | jq -r .unseal_keys_hex[0])

    PRI_ROOT_TOKEN=$(echo "$initoutput" | jq -r .root_token)

}

function start_secondary() {
    echo "* start secondary"

    mkdir -p ${tmpdir}/vault-sec-data

cat - > ${tmpdir}/vault-sec.hcl <<EOF
pid_file = "${tmpdir}/sec_pid_file"

listener "tcp" {
    address = "0.0.0.0:8202"
    tls_disable = 1
}

storage "file" {
    path = "${tmpdir}/vault-sec-data"
}

seal "transit" {
  address            = "http://127.0.0.1:8200"
  tls_skip_verify    = "true"
  disable_renewal    = "false"
  mount_path         = "transit/"
  key_name           = "unseal-key"
}
EOF

    vault server -config=${tmpdir}/vault-sec.hcl -log-level=debug >> ${tmpdir}/vault-sec.log 2>&1 &

    while ! nc -z localhost 8202; do
      sleep 1
      echo -n '.'
    done
    echo
}

function kill_secondary() {
    echo "* kill secondary"
    kill $(cat ${tmpdir}/sec_pid_file)

    while nc -z localhost 8202 || test -f ${tmpdir}/pidfile; do
      sleep 1
      echo -n '.'
    done
    sleep 1
    echo
}

# ------------------------------------------------
# ------------- Script starts here ---------------
# ------------------------------------------------

start_primary

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN="$PRI_ROOT_TOKEN"

vault secrets enable transit

# 1a: create transit key
vault write -force /transit/keys/unseal-key

# 1b: create policy to access transit key
vault policy write use-unseal-key <(cat - <<EOF
path "/transit/encrypt/unseal-key" {
    capabilities = ["update"]
}
path "/transit/decrypt/unseal-key" {
    capabilities = ["update"]
}
EOF
)

# 1c: create token tied to policy
PRI_TRANSIT_TOKEN=$(vault token create -policy=use-unseal-key -field=token)

# Start and init secondary
VAULT_TOKEN="$PRI_TRANSIT_TOKEN" start_secondary

export VAULT_ADDR=http://localhost:8202
initoutput=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
export VAULT_TOKEN=$(echo "$initoutput" | jq -r .root_token)

# Test that secondary can be killed and restarted and auto-unsealed
vault secrets enable kv
vault kv put kv/foo val=1

kill_secondary
VAULT_TOKEN="$PRI_TRANSIT_TOKEN" start_secondary

vault kv get kv/foo

