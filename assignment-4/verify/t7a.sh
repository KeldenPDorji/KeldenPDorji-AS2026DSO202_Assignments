#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t7a
hdr "before"; echo "dev frontend RS: $(active_rs dso202-dev frontend) RELEASE=$(rel dso202-dev frontend)"; appstate tasktracker-staging
ruby "$A4/verify/set-env.rb" frontend RELEASE=1.1
ship release/frontend-1.1 "Release 1.1: frontend configuration"; H=$(git rev-parse HEAD); refresh tasktracker-dev; wait_op tasktracker-dev "$H"; wait_smoke dso202-dev
hdr "dev after the merge (no kubectl apply, no argocd sync)"; echo "commit: $(git log --oneline -1)"; echo "dev frontend RS: $(active_rs dso202-dev frontend) RELEASE=$(rel dso202-dev frontend)"; appstate tasktracker-dev
kubectl get job -n dso202-dev --no-headers | awk '{print "smoke test:",$1,$2}'
hdr "staging is untouched: it reads tag v1.0.0"; appstate tasktracker-staging; echo "staging frontend RELEASE=$(rel dso202-staging frontend)"
hdr "dev history"; argocd app history tasktracker-dev 2>&1 | tail -4 | cut -c1-80
