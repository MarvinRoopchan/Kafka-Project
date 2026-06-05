#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="${ROOT_DIR}/k8s/secret.yaml"

if [[ -z "${DB_PASSWORD:-}" ]]; then
  echo "Set DB_PASSWORD before running this script."
  echo "  export DB_PASSWORD='your-secure-password'"
  exit 1
fi

cd "${ROOT_DIR}"

RDS_ENDPOINT="$(terraform output -raw rds_endpoint)"
MSK_BROKERS="$(terraform output -raw msk_bootstrap_brokers)"
DB_USER="$(terraform output -raw rds_master_user 2>/dev/null || echo "marvin_user")"

cat > "${OUT_FILE}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: romanstream
type: Opaque
stringData:
  DB_HOST: "${RDS_ENDPOINT}"
  DB_USER: "${DB_USER}"
  DB_PASS: "${DB_PASSWORD}"
  KAFKA_BOOTSTRAP_SERVERS: "${MSK_BROKERS}"
EOF

echo "Wrote ${OUT_FILE}"
echo "Apply with: kubectl apply -f k8s/secret.yaml"
