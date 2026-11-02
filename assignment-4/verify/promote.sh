#!/bin/bash
# promote.sh <tag>: tag main, move staging to it by pull request, then sync by hand.
source "$(dirname "$0")/lib.sh"; T=$1; cap "promote-$T"
git tag -a "$T" -m "Release $T"; git push -q origin "$T"
sed -i '' "s/^    targetRevision: v[0-9.]*/    targetRevision: $T/" argocd/applications/tasktracker-staging.yaml
hdr "pull request moves the gate to $T"; ship "promote/$T" "Promote staging to $T"; git log --oneline -1
refresh root; kubectl wait --for=jsonpath="{.spec.source.targetRevision}=$T" application/tasktracker-staging -n argocd --timeout=180s >/dev/null
refresh tasktracker-staging; kubectl wait --for=jsonpath='{.status.sync.status}=OutOfSync' application/tasktracker-staging -n argocd --timeout=120s >/dev/null
hdr "merged, but nothing deployed: staging waits for a person"; appstate tasktracker-staging; echo "frontend RELEASE=$(rel dso202-staging frontend) backend RELEASE=$(rel dso202-staging backend)"
hdr "manual sync"; argocd app sync tasktracker-staging --timeout 280 2>&1 | grep -E '^(Phase|Sync Status|Health Status):'
wait_app tasktracker-staging; wait_smoke dso202-staging
hdr "after"; appstate tasktracker-staging; echo "frontend RELEASE=$(rel dso202-staging frontend) backend RELEASE=$(rel dso202-staging backend)"
