#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t9
pkill -f 'port-forward svc/argocd-server' 2>/dev/null
ela() { echo "+$(( $(date +%s)-T0 ))s  $*"; }
hdr "before"; echo "HEAD $(git rev-parse --short HEAD)"; apps
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ../dso202-keys/sealing-key.backup.yaml; chmod 600 ../dso202-keys/sealing-key.backup.yaml
hdr "rebuild"; date; kind delete cluster --name dso202-gitops >/dev/null 2>&1
T0=$(date +%s); kind create cluster --name dso202-gitops --config cluster/kind-cluster.yaml >/dev/null 2>&1; kubectl wait --for=condition=Ready node --all --timeout=300s >/dev/null; ela "cluster ready"
kubectl create namespace sealed-secrets >/dev/null; kubectl apply -f ../dso202-keys/sealing-key.backup.yaml >/dev/null; ela "sealing key restored before the controller exists"
kubectl apply -k bootstrap/argocd --server-side --force-conflicts >/dev/null; kubectl wait --for=condition=Available deployment --all -n argocd --timeout=600s >/dev/null; kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s >/dev/null; ela "Argo CD ready"
kubectl apply -f bootstrap/root >/dev/null 2>&1; ela "root applied"
kubectl wait --for=create deployment/sealed-secrets-controller -n sealed-secrets --timeout=400s >/dev/null; kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets --timeout=400s >/dev/null; ela "wave -2: sealed-secrets"
for e in dev staging; do kubectl wait --for=create secret/tasktracker-credentials -n dso202-$e --timeout=400s >/dev/null; kubectl wait --for=create application/platform-$e -n argocd --timeout=60s >/dev/null; wait_app platform-$e 400s; ela "wave -1: platform-$e (restored key decrypted its SealedSecret)"; done
kubectl wait --for=create job/tasktracker-smoke-test -n dso202-dev --timeout=600s >/dev/null; wait_smoke dso202-dev; wait_app tasktracker-dev 400s; ela "wave 0: tasktracker-dev"
echo "dev frontend -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:30080/)"; ela "working dev frontend"
kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 & PF=$!; disown; until curl -sk -o /dev/null https://localhost:8080/healthz; do :; done
argocd login localhost:8080 --username admin --password "$(argocd admin initial-password -n argocd | head -1)" --insecure >/dev/null 2>&1
argocd app sync tasktracker-staging --timeout 280 2>&1 | grep -E '^Sync Status:'; wait_app tasktracker-staging; wait_smoke dso202-staging; ela "staging synced by hand"; kill $PF
hdr "after"; apps
for e in dev staging; do echo "$e new task: $(kubectl exec -n dso202-$e deploy/tasktracker-frontend -- curl -s -X POST http://tasktracker-backend:8080/api/tasks -H 'Content-Type: application/json' -d '{"title":"after rebuild"}' | jq -c '{id,title}')"; done
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ../dso202-keys/sealing-key.backup.yaml; chmod 600 ../dso202-keys/sealing-key.backup.yaml; ls -l ../dso202-keys/ | tail -1 | awk '{print "fresh backup:",$1,$NF}'; date
