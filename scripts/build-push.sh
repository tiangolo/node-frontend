#!/usr/bin/env bash

set -e
set -x

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

TAG=${TAG:-10}

docker build -t tiangolo/node-frontend:${TAG} .

docker tag tiangolo/node-frontend:${TAG} tiangolo/node-frontend:latest

docker push tiangolo/node-frontend:${TAG}

docker push tiangolo/node-frontend:latest
