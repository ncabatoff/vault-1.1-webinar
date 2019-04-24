# Vault 1.1 Webinar demos

To run these demos you will need in your path:
* vault
* jq
* docker
* docker-compose

## Demo 1: OIDC

See [README.oidc](README-oidc.md).

## Demo 2: Vault Agent Cache

To run:

```bash
cd demo-agent
./launch-demo.sh
```

Go to http://localhost:3000 to access Grafana.

## Demo 3: Transit auto-unseal

To Run:

```bash
./demo-transit-autounseal.sh
```
