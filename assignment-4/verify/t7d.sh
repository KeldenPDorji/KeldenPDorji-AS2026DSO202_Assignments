#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t7d
ruby "$A4/verify/set-env.rb" backend RELEASE=1.2 DB_HOST=tasktracker-db
ship release/backend-1.2-fixed "Release 1.2: backend, DB_HOST corrected"; H=$(git rev-parse HEAD); refresh tasktracker-dev; wait_op tasktracker-dev "$H" 600s; wait_smoke dso202-dev
hdr "fix-forward in dev"; git log --oneline -1; appstate tasktracker-dev; echo "backend RELEASE=$(rel dso202-dev backend) DB_HOST=$(kubectl exec -n dso202-dev deploy/tasktracker-backend -- printenv DB_HOST)"
kubectl get job -n dso202-dev --no-headers | awk '{print "smoke test:",$1,$2}'
