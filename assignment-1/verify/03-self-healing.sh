#!/bin/bash
# Task 7c - self-healing AND data persistence, in one transcript.
#
# The claim being proved: Pod lifecycle and PersistentVolume lifecycle are
# INDEPENDENT. A task written before the backend Pod is destroyed is still
# retrievable after the ReplicaSet builds a replacement, because the row lives
# on the PVC-backed database volume, not inside the backend Pod.
#
# Every HTTP call is made from inside the frontend Pod, through backend-svc.
# That deliberately avoids a host port-forward: a port-forward is pinned to one
# Pod and would die along with the Pod we are about to delete, whereas the
# Service keeps resolving straight through to the replacement.
set -eu
NS=dso202-assignment-01
FE=$(kubectl get pod -n "$NS" -l tier=frontend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
API=http://backend-svc:8080/api/tasks

echo "===== 1. create a task through backend-svc, from the frontend Pod ====="
NEW=$(kubectl exec -n "$NS" "$FE" -- curl -s -X POST "$API" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Survives Pod deletion","description":"Written to the PVC-backed database before the Pod is killed"}')
echo "$NEW" | jq -c '{id, title, status}'
ID=$(echo "$NEW" | jq -r .id)

OLD_POD=$(kubectl get pod -n "$NS" -l tier=backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
OWNER=$(kubectl get pod -n "$NS" "$OLD_POD" -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}')
echo
echo "backend Pod before deletion : $OLD_POD"
echo "owned by                    : $OWNER   <- this is what will rebuild it"

echo
echo "===== 2. delete the Pod and watch the ReplicaSet rebuild it ====="
kubectl get pods -n "$NS" -l tier=backend --watch &
WATCH_PID=$!
sleep 2
kubectl delete pod -n "$NS" "$OLD_POD"
sleep 25
kill "$WATCH_PID" 2>/dev/null || true
wait "$WATCH_PID" 2>/dev/null || true

NEW_POD=$(kubectl get pod -n "$NS" -l tier=backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo
echo "backend Pod after deletion  : $NEW_POD"
echo "                              (different name = a genuinely new Pod, not a restart)"

echo
echo "===== 3. the database Pod and its PVC were never touched ====="
kubectl get pvc -n "$NS"
kubectl get pod -n "$NS" -l tier=database

echo
echo "===== 4. read task id ${ID} back through the NEW backend Pod ====="
kubectl exec -n "$NS" "$FE" -- curl -s "$API/$ID" | jq .
echo
echo "Same row, new Pod: the data lived on the PersistentVolume, not in the Pod."
