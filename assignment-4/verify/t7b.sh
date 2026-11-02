#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t7b
ruby "$A4/verify/set-env.rb" backend RELEASE=1.2 DB_HOST=tasktracker-database
ship release/backend-1.2 "Release 1.2: backend configuration"; BAD=$(git rev-parse HEAD); echo "$BAD" > "$A4/outputs/bad-sha.txt"; refresh tasktracker-dev
hdr "bad commit"; git log --oneline -1
kubectl wait --for=jsonpath='{.status.conditions[?(@.type=="Progressing")].reason}=ProgressDeadlineExceeded' deployment/tasktracker-backend -n dso202-dev --timeout=300s >/dev/null
kubectl wait --for=jsonpath='{.status.health.status}=Degraded' application/tasktracker-dev -n argocd --timeout=120s >/dev/null
hdr "observed, without intervening"; kubectl get pods -n dso202-dev -l app.kubernetes.io/component=backend --no-headers | awk '{print $1,$2,$3}'; appstate tasktracker-dev; appstate tasktracker-staging
echo "smoke test for this revision: $(kubectl get application tasktracker-dev -n argocd -o json | jq -r --arg b "$BAD" "if .status.operationState.phase==\"Succeeded\" and .status.operationState.syncResult.revision==\$b then \"ran\" else \"did not run: the sync never reached PostSync\" end")"
echo "old Pod still serving: $(kubectl exec -n dso202-dev deploy/tasktracker-frontend -- curl -s http://tasktracker-backend:8080/api/status)"
NEW=$(kubectl get pods -n dso202-dev -l app.kubernetes.io/component=backend --no-headers | awk '$2=="0/1"{print $1; exit}')
hdr "diagnosis"; kubectl describe pod "$NEW" -n dso202-dev | grep -E 'Readiness probe failed|DB_HOST:' | tail -2 | sed 's/^ *//' | cut -c1-96; echo "log: $(kubectl logs "$NEW" -n dso202-dev --tail=1)"
hdr "argocd app rollback"; argocd app rollback tasktracker-dev 2>&1 | tail -1 | jq -r .msg 2>/dev/null | cut -c1-110
