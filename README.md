# MuchToDo — Containerization & Kubernetes Deployment

A Golang + MongoDB REST API containerized with Docker and deployed to a local Kubernetes cluster using Kind.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Docker | 20.10+ |
| Docker Compose | v2+ |
| Kind | 0.20+ |
| kubectl | 1.27+ |

---

## Repository Structure

```
.
├── Server/MuchToDo/          # Go application source code
├── Dockerfile                # Multi-stage Docker build
├── docker-compose.yml        # Local development stack
├── .dockerignore             # Files excluded from Docker build context
├── kubernetes/
│   ├── namespace.yaml
│   ├── mongodb/
│   │   ├── mongodb-secret.yaml
│   │   ├── mongodb-configmap.yaml
│   │   ├── mongodb-pvc.yaml
│   │   ├── mongodb-deployment.yaml
│   │   └── mongodb-service.yaml
│   ├── backend/
│   │   ├── backend-secret.yaml
│   │   ├── backend-configmap.yaml
│   │   ├── backend-deployment.yaml
│   │   └── backend-service.yaml
│   └── ingress.yaml
├── scripts/
│   ├── docker-build.sh       # Build the Docker image
│   ├── docker-run.sh         # Run the full stack with docker compose
│   ├── k8s-deploy.sh         # Deploy everything to Kind
│   └── k8s-cleanup.sh        # Tear down the Kind cluster
└── evidence/                 # Screenshots of running deployments
```

---

## Phase 1: Docker

### Environment Variables

Create a `.env` file in the project root (optional — defaults are provided):

```env
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=adminpassword
DB_NAME=much_todo_db
JWT_SECRET_KEY=change-me-in-production
JWT_EXPIRATION_HOURS=72
APP_PORT=8080
LOG_LEVEL=DEBUG
LOG_FORMAT=json
```

### Build the image

```bash
./scripts/docker-build.sh
```

### Run with Docker Compose

```bash
./scripts/docker-run.sh
```

This starts:
- **MongoDB** on internal port `27017` (with health check)
- **Backend API** on `http://localhost:8080`

### Verify

```bash
# Health check
curl http://localhost:8080/health

# API root
curl http://localhost:8080/

# Swagger UI
open http://localhost:8080/swagger/index.html
```

### Stop

```bash
docker compose down
# To also remove volumes:
docker compose down -v
```

---

## Phase 2: Kubernetes (Kind)

### Deploy everything

The deploy script handles cluster creation, image build, image loading, ingress controller installation, and manifest application:

```bash
./scripts/k8s-deploy.sh
```

### Access the application

**Via NodePort (recommended for Kind):**

```bash
curl http://localhost:30080/health
```

**Via Ingress:**

Add the following to `/etc/hosts`:
```
127.0.0.1  muchtodo.local
```

Then:
```bash
curl http://muchtodo.local/health
```

### Useful kubectl commands

```bash
# Check all resources in the namespace
kubectl get all -n muchtodo

# Check pod status
kubectl get pods -n muchtodo

# Check services
kubectl get svc -n muchtodo

# Check ingress
kubectl get ingress -n muchtodo

# View backend logs
kubectl logs -l app=muchtodo-backend -n muchtodo --tail=50

# Describe a pod
kubectl describe pod -l app=muchtodo-backend -n muchtodo
```

### Cleanup

```bash
./scripts/k8s-cleanup.sh
```

---

## Application Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check (database status) |
| GET | `/ping` | Simple ping |
| POST | `/auth/register` | Register a new user |
| POST | `/auth/login` | Login and receive JWT |
| POST | `/auth/logout` | Logout |
| GET | `/user/me` | Get current user (auth required) |
| GET | `/todos` | List todos (auth required) |
| POST | `/todos` | Create todo (auth required) |
| PUT | `/todos/:id` | Update todo (auth required) |
| DELETE | `/todos/:id` | Delete todo (auth required) |

Full API documentation available at `/swagger/index.html`.

---

## Architecture

```
                    ┌─────────────────────────────┐
                    │        Kind Cluster          │
                    │                              │
  localhost:30080 ──┤──► backend-service (NodePort)│
  muchtodo.local ───┤──► ingress-nginx             │
                    │         │                    │
                    │         ▼                    │
                    │  muchtodo-backend (x2 pods)  │
                    │         │                    │
                    │         ▼                    │
                    │  mongodb-service (ClusterIP) │
                    │         │                    │
                    │         ▼                    │
                    │   mongodb pod + PVC (1Gi)    │
                    └─────────────────────────────┘
```
