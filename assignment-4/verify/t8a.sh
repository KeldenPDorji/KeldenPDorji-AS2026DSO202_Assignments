#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t8a
D=tasktracker-backend
hdr "drill 1: prediction: self-heal returns dev to 1 replica without anyone acting"
kubectl get deployment/$D -n dso202-dev --watch --no-headers & W=$!
kubectl scale deployment/$D -n dso202-dev --replicas=3; S=$(date +%s)
kubectl wait --for=jsonpath='{.spec.replicas}=1' deployment/$D -n dso202-dev --timeout=120s >/dev/null; E=$(( $(date +%s)-S )); kill $W 2>/dev/null; wait $W 2>/dev/null
echo "reverted to spec.replicas=1 after ${E}s"; wait_app tasktracker-dev 180s; appstate tasktracker-dev
hdr "drill 2: prediction: staging is reported OutOfSync but stays at 3 replicas until synced"
kubectl scale deployment/$D -n dso202-staging --replicas=3; refresh tasktracker-staging
kubectl wait --for=jsonpath='{.status.sync.status}=OutOfSync' application/tasktracker-staging -n argocd --timeout=120s >/dev/null
appstate tasktracker-staging; echo "live replicas: $(kubectl get deployment/$D -n dso202-staging -o jsonpath='{.spec.replicas}')"
argocd app diff tasktracker-staging 2>&1 | grep -E '^(=====|[<>])' | cut -c1-70
argocd app sync tasktracker-staging --timeout 200 2>&1 | grep -E '^(Phase|Sync Status):'
echo "live replicas after sync: $(kubectl get deployment/$D -n dso202-staging -o jsonpath='{.spec.replicas}')"; appstate tasktracker-staging
