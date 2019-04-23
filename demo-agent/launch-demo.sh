#!/usr/bin/env bash

cd $(dirname $0)/badapp
GOOS=linux go build

cd $(dirname $0)
docker-compose down
docker-compose rm -f
docker kill vault
docker rm badapp vault
docker-compose up
