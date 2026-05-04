#!/usr/bin/env bash
set -euo pipefail

echo "==> Starting MuchToDo with docker compose..."

docker compose up --build -d

echo ""
echo "==> Waiting for services to become healthy..."
sleep 5

docker compose ps

echo ""
echo "==> Application is running."
echo "    Backend:  http://localhost:${APP_PORT:-8080}"
echo "    Health:   http://localhost:${APP_PORT:-8080}/health"
echo "    Swagger:  http://localhost:${APP_PORT:-8080}/swagger/index.html"
echo ""
echo "To tail logs:  docker compose logs -f"
echo "To stop:       docker compose down"
