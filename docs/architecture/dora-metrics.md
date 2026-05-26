# DORA Metrics — CloudNative Platform

## What are DORA Metrics?

DORA (DevOps Research and Assessment) identified 4 metrics that
predict software delivery performance and org outcomes.
Elite performers score high on all 4.

## The 4 Metrics

### 1. Deployment Frequency
**What:** How often you deploy to production
**Elite:** Multiple times per day
**Our target:** Daily (Phase 4 goal)
**How we measure:** GitHub Actions CD workflow runs per day
```
# Prometheus query
increase(github_actions_workflow_runs_total{
  workflow="CD",
  status="success"
}[24h])
```

### 2. Lead Time for Changes
**What:** Time from code commit to running in production
**Elite:** Less than 1 hour
**Our target:** Under 30 minutes
**How we measure:** Time from git push to ArgoCD sync complete
```
# Measure: git commit timestamp → ArgoCD sync timestamp
# Tracked in Grafana DORA dashboard
```

### 3. Change Failure Rate
**What:** Percentage of deployments causing incidents
**Elite:** 0-15%
**Our target:** Under 10%
**How we measure:** Rollbacks / total deployments
```
# A rollback = Argo Rollouts auto-rollback or manual revert commit
# Track: git reverts + argo rollback events in Prometheus
```

### 4. Mean Time to Recovery (MTTR)
**What:** Time to restore service after incident
**Elite:** Less than 1 hour
**Our target:** Under 30 minutes
**How we measure:** PagerDuty incident open → resolve time

## Where to See These Metrics

Grafana dashboard: `observability/dashboards/dora-metrics.json`

## Why This Matters for Interviews

When asked "how do you measure DevOps success?" — most candidates
say "uptime" or "deployment speed". DORA metrics show you think
like a senior engineer who measures outcomes, not just activity.
