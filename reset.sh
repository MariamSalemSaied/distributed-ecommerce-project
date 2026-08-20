#!/usr/bin/env bash
set -euo pipefail
docker compose down -v --remove-orphans
echo "Cluster and Docker volumes removed."
echo "Run ./setup.sh to create a fresh cluster."
