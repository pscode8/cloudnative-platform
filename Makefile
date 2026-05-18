.PHONY: help dev down logs test test-api lint build scan

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | 	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

dev: ## Start full local stack
	docker compose up --build

dev-bg: ## Start in background
	docker compose up --build -d

down: ## Stop everything
	docker compose down -v

logs: ## Tail logs
	docker compose logs -f

test: ## Run all tests
	docker compose run --rm api pytest tests/ -v

test-api: ## Run API tests with coverage
	docker compose run --rm api pytest tests/ -v 	  --cov=src --cov-report=term-missing --cov-report=xml

lint: ## Run pre-commit on all files
	pre-commit run --all-files

build: ## Build Docker images
	docker build -t cloudnative/api:local ./apps/api

scan: ## Scan images for CVEs
	trivy image cloudnative/api:local

shell-api: ## Open shell in running API container
	docker compose exec api bash

db-migrate: ## Run Alembic migrations
	docker compose run --rm api alembic upgrade head

db-shell: ## Open psql shell
	docker compose exec postgres psql -U appuser -d appdb
