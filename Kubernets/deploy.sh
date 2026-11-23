#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f manifests/database-secret.yaml ]; then
  echo 'Copy manifests/database-secret.yaml.example to manifests/database-secret.yaml and set the two values first.'
  exit 1
fi

# Build the application and copy its image into the local kind node.
docker build -t krishna-database-web:v1 ./web
"$HOME/.local/bin/kind" load docker-image krishna-database-web:v1 --name learning
kubectl --context kind-learning apply -f manifests/namespace.yaml

# Apply the separate Secret along with the other resources.
kubectl --context kind-learning apply -f manifests/
kubectl --context kind-learning -n krishna rollout status deployment/postgres --timeout=180s
# Restart also picks up a rebuilt image with the same local lab tag.
kubectl --context kind-learning -n krishna rollout restart deployment/website
kubectl --context kind-learning -n krishna rollout status deployment/website --timeout=180s
