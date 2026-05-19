# Apply all changes, then:
docker build -t cloudnative/api:ci --target prod ./apps/api

# Scan locally first to verify zero CRITICAL hits
trivy image --severity CRITICAL,HIGH \
  --ignorefile apps/api/.trivyignore \
  cloudnative/api:ci

# Commit everything
git add apps/api/Dockerfile \
        apps/api/.trivyignore \
        .github/workflows/ci.yml \
        .github/renovate.json

git commit -m "fix(security): harden prod image with chainguard, add renovate, VEX trivyignore"
git push origin feature/phase1-docker-api
