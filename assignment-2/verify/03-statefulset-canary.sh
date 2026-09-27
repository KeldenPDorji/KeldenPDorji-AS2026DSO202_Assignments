#!/bin/bash
# 2.1.8 - canary rollout with updateStrategy.rollingUpdate.partition, then
# 2.1.9 - PVC retention on scale-down.
#
# partition: N means only ordinals >= N are updated when the Pod template
# changes. Everything below N is left untouched, so a change can be validated
# against one replica before it reaches the rest.
#
# Requires the StatefulSet to be at 3 replicas (run 02-statefulset-identity.sh
# first).
set -eu
NS=dso202-assignment-02
COLS='custom-columns=NAME:.metadata.name,REVISION:.metadata.labels.controller-revision-hash,CONFIG_REVISION:.spec.containers[0].env[?(@.name=="CONFIG_REVISION")].value'

echo "===== 1. every ordinal is currently on the same template revision ====="
kubectl get pods -n "$NS" -l tier=database -o "$COLS"

echo
echo "===== 2. hold back everything below ordinal 2 ====="
kubectl patch statefulset db -n "$NS" --type=json -p='[{"op":"replace","path":"/spec/updateStrategy/rollingUpdate/partition","value":2}]'

echo
echo "===== 3. change the Pod template ====="
echo "(any template change triggers a rollout; partition decides who receives it)"
kubectl set env statefulset/db -n "$NS" CONFIG_REVISION=2
kubectl rollout status statefulset/db -n "$NS" --timeout=900s

echo
echo "===== 4. ONLY db-2 took the change ====="
kubectl get pods -n "$NS" -l tier=database -o "$COLS"
echo "db-0 and db-1 still run the previous revision, with CONFIG_REVISION unset."

echo
echo "===== 5. release the rest of the rollout ====="
kubectl patch statefulset db -n "$NS" --type=json -p='[{"op":"replace","path":"/spec/updateStrategy/rollingUpdate/partition","value":0}]'
kubectl rollout status statefulset/db -n "$NS" --timeout=900s
kubectl get pods -n "$NS" -l tier=database -o "$COLS"
echo "Updated in DESCENDING ordinal order, one at a time, each Ready before the next."

echo
echo "===== 6. revision history is recorded, exactly as a Deployment's is ====="
kubectl rollout history statefulset/db -n "$NS"

echo
echo "===== 7. scale back down to 1 ====="
kubectl scale statefulset db -n "$NS" --replicas=1
kubectl wait --for=delete pod/db-2 pod/db-1 -n "$NS" --timeout=300s
kubectl get pods -n "$NS" -l tier=database --no-headers
echo "Deletion runs in reverse ordinal order: db-2 first, then db-1."

echo
echo "===== 8. the PVCs of the removed ordinals were RETAINED ====="
kubectl get pvc -n "$NS" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage
kubectl get statefulset db -n "$NS" -o jsonpath='persistentVolumeClaimRetentionPolicy = {.spec.persistentVolumeClaimRetentionPolicy}{"\n"}'
echo "whenScaled: Retain means scaling down deletes Pods but never their data."
echo "Scaling back to 3 would reattach data-db-1 and data-db-2 to their ordinals."

echo
echo "===== 9. restore the declared state ====="
# NOTE: `kubectl apply` alone does NOT undo `kubectl set env`. The env var was
# never in the last-applied-configuration annotation, so the three-way merge
# treats it as a field owned by someone else and preserves it. It has to be
# removed explicitly with the trailing-dash syntax - a concrete instance of the
# imperative/declarative divergence Assignment 1 examined.
kubectl set env statefulset/db -n "$NS" CONFIG_REVISION-
kubectl apply -f database/statefulset.yaml
kubectl rollout status statefulset/db -n "$NS" --timeout=900s
kubectl get pods -n "$NS" -l tier=database -o "$COLS"
