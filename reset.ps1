$ErrorActionPreference = "Stop"
docker compose down -v --remove-orphans
Write-Host "Cluster and Docker volumes removed."
Write-Host "Run .\setup.ps1 to create a fresh cluster."
