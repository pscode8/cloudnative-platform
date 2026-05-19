# 1. Create on GitHub first (add README, .gitignore: Python, Node)
#    Repo name: cloudnative-platform
#    Visibility: Public  ← this matters for your portfolio

# 2. Clone locally
git clone git@github.com:pscode8/cloudnative-platform.git
cd cloudnative-platform

# 3. Set your identity (if not global)
git config user.name "pscode8"
git config user.email "npartha2201@gmail.com"

# 4. Create the base folder structure (all at once)
mkdir -p apps/api/src apps/api/tests \
         apps/frontend/src apps/frontend/tests \
         apps/worker/src \
         infra/terraform/modules \
         infra/terraform/environments/{dev,staging,prod} \
         infra/ansible/{roles,playbooks} \
         charts/{api,frontend,worker} \
         gitops/argocd/projects \
         gitops/environments/{dev,staging,prod} \
         observability/{dashboards,alerts,runbooks} \
         security/{policies,vault,falco} \
         .github/workflows \
         docs/{architecture,runbooks}

# 5. Add .gitkeep so git tracks empty dirs
find . -type d -empty -not -path './.git/*' -exec touch {}/.gitkeep \;

# 6. Initial commit
git add .
git commit -m "chore: initialize monorepo structure"
git push origin main
