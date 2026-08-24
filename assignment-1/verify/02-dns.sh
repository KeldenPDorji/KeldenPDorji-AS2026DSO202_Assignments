#!/bin/sh
# Task 7b - Service DNS resolution from INSIDE the frontend Pod.
#
# Proves three things at once:
#   1. the Pod received BACKEND_URL from the ConfigMap;
#   2. cluster DNS resolves `backend-svc` to the Service's ClusterIP;
#   3. `db-svc` - being headless - resolves straight to the database POD IP,
#      which is the whole point of clusterIP: None.
set -eu
NS=dso202-assignment-01
POD=$(kubectl get pod -n "$NS" -l tier=frontend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo "exec into frontend Pod: $POD"
echo

kubectl exec -n "$NS" "$POD" -- sh -c '
echo "### BACKEND_URL injected from the ConfigMap: $BACKEND_URL"
echo
echo "### backend-svc resolves to the Service ClusterIP"
getent hosts backend-svc
echo
echo "### db-svc is headless, so it resolves to the database Pod IP"
getent hosts db-svc
echo
echo "### reach the backend BY NAME, no IP anywhere"
curl -s http://backend-svc:8080/api/status; echo'

echo
echo "### compare against the real objects:"
kubectl get svc -n "$NS" -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP
kubectl get pod -n "$NS" -l tier=database -o custom-columns=NAME:.metadata.name,POD-IP:.status.podIP
