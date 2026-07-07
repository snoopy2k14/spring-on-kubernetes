#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# --- preflight: fail fast if tooling is missing ---
for cmd in kind kubectl helm docker; do
  command -v "$cmd" >/dev/null || { echo "Missing required tool: $cmd"; exit 1; }
done

echo "Installing kind"
if kind get clusters 2>/dev/null | grep -qx "local"; then
  echo "kind cluster 'local' already exists, skipping"
else
  ../config/kind/deploy.sh
fi

echo "Installing ingress"
../config/ingress/deploy.sh
echo "Waiting for ingress controller to be ready"
kubectl wait --namespace ingress-nginx \
  --for=condition=Available deployment/ingress-nginx-controller \
  --timeout=180s

echo "Installing monitoring"
../config/monitoring/deploy.sh
echo "Waiting for monitoring stack to be ready"
kubectl wait --namespace monitoring \
  --for=condition=Available deployment --all \
  --timeout=300s

echo "Installing postgres"
../config/postgres/deploy.sh

echo "Waiting for postgres cluster to be ready"
kubectl -n postgres wait --for=condition=Ready cluster/localdb --timeout=300s

./populate-db.sh
