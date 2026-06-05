#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f k8s/secret.yaml ]]; then
  echo "k8s/secret.yaml not found. Run ./scripts/create-k8s-secret.sh first."
  exit 1
fi

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/producer.yaml
kubectl apply -f k8s/consumer.yaml
kubectl apply -f k8s/api.yaml
kubectl apply -f k8s/fe.yaml

echo ""
echo "Deployments applied. Check status:"
echo "  kubectl get pods -n romanstream"
echo ""
echo "Get frontend URL:"
echo "  kubectl get svc fe -n romanstream"
