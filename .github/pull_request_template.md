cat > .github/pull_request_template.md << 'EOF'
## What does this PR do?
<!-- Brief description -->

## Type of change
- [ ] feat: new feature
- [ ] fix: bug fix
- [ ] chore: tooling/config
- [ ] infra: terraform/ansible
- [ ] ci: pipeline change
- [ ] docs: documentation

## Checklist
- [ ] `make lint` passes locally
- [ ] `make test` passes locally
- [ ] No secrets or credentials committed
- [ ] README updated if needed
EOF
