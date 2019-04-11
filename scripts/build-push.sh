#!/usr/bin/env bash

set -e
set -x

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

docker build -t tiangolo/node-frontend:10 .

docker build -t tiangolo/node-frontend:latest .

docker push tiangolo/node-frontend:10

docker push tiangolo/node-frontend:latest
