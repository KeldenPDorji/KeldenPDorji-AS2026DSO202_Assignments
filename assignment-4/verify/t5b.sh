#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t5b
kubectl port-forward -n dso202-dev svc/tasktracker-backend 18081:8080 >/dev/null 2>&1 & PF=$!; disown; trap 'kill $PF 2>/dev/null' EXIT
until curl -s -o /dev/null localhost:18081/api/status; do :; done
API=localhost:18081/api/tasks
hdr "CRUD in dev, through a port-forwarded backend"
N=$(curl -s -X POST $API -H 'Content-Type: application/json' -d '{"title":"GitOps CRUD","description":"created in dev"}'); ID=$(echo "$N" | jq -r .id); echo "POST   -> $(echo "$N" | jq -c '{id,title,status}')"
echo "GET    -> $(curl -s $API | jq -c 'map(.id)')"
echo "PUT    -> $(curl -s -X PUT $API/$ID -H 'Content-Type: application/json' -d '{"title":"GitOps CRUD","description":"updated","status":"done"}' | jq -c '{id,status}')"
echo "DELETE -> HTTP $(curl -s -o /dev/null -w '%{http_code}' -X DELETE $API/$ID)"
echo "GET    -> $(curl -s $API | jq -c 'map(.id)')"
kill $PF; hdr "frontend"; echo "dev  http://localhost:30080 -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:30080/)"
hdr "staging sync (the manual gate)"; argocd app sync tasktracker-staging --timeout 280 2>&1 | grep -E '^(Phase|Sync Status|Health Status):'
kubectl wait --for=jsonpath='{.status.health.status}=Healthy' application/tasktracker-staging -n argocd --timeout=120s >/dev/null; wait_smoke dso202-staging
kubectl port-forward -n dso202-staging svc/tasktracker-frontend 18082:8080 >/dev/null 2>&1 & PF=$!; disown
until curl -s -o /dev/null localhost:18082/; do :; done; echo "staging port-forward -> HTTP $(curl -s -o /dev/null -w '%{http_code}' localhost:18082/)"; kill $PF
hdr "after staging sync"; apps; kubectl get svc tasktracker-frontend -n dso202-staging --no-headers | awk '{print $1,$2,$5}'
