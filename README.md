# CloudNative Platform

[![CI](https://github.com/YOUR_USERNAME/cloudnative-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/cloudnative-platform/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-blue?logo=kubernetes)](https://kubernetes.io)
[![Terraform](https://img.shields.io/badge/Terraform-1.8-purple?logo=terraform)](https://terraform.io)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange)](https://argoproj.github.io)

> Enterprise-grade cloud-native platform demonstrating production DevOps practices:
> GitOps, IaC, observability, security, and zero-downtime deployments.

## Stack

| Layer | Technology |
|---|---|
| App | FastAPI, PostgreSQL, Redis, Kafka |
| Containers | Docker multi-stage, Docker Compose |
| Orchestration | Kubernetes (EKS), Helm, Kustomize |
| IaC | Terraform (modules), Ansible |
| CI/CD | GitHub Actions, ArgoCD, Argo Rollouts |
| Observability | Prometheus, Grafana, Loki, Tempo, OpenTelemetry |
| Security | Vault, Trivy, Falco, OPA Gatekeeper |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/cloudnative-platform
cd cloudnative-platform
cp .env.example .env
make dev
```

| Service | URL |
|---|---|
| API | http://localhost:8000 |
| API Docs | http://localhost:8000/docs |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 (admin/admin) |

## Project Structure

```
cloudnative-platform/
├── apps/api/          # FastAPI backend
├── apps/frontend/     # React frontend
├── infra/terraform/   # AWS infrastructure
├── infra/ansible/     # Config management
├── charts/            # Helm charts
├── gitops/            # ArgoCD manifests
├── observability/     # Prometheus, Grafana configs
└── .github/workflows/ # CI/CD pipelines
```

## License
MIT# cloudnative-platform
