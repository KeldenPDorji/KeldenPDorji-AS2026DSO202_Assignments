#!/bin/bash
# Task 7d - the SAME resource created two ways, then compared.
#
# Subject: the application ConfigMap. It is the best candidate here because it
# carries seven keys, so the difference in effort and in reviewability between
# the two approaches is visible rather than theoretical.
set -eu
NS=dso202-assignment-01

echo "===== DECLARATIVE : kubectl apply -f configmap.yaml ====="
kubectl apply -f configmap.yaml
echo

echo "===== IMPERATIVE : the equivalent kubectl create command ====="
kubectl delete configmap app-config-imperative -n "$NS" --ignore-not-found
kubectl create configmap app-config-imperative -n "$NS" \
  --from-literal=DB_HOST=db-svc \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=taskdb \
  --from-literal=APP_PORT=8080 \
  --from-literal=CORS_ORIGIN='*' \
  --from-literal=POSTGRES_DB=taskdb \
  --from-literal=BACKEND_URL=http://backend-svc:8080
echo

echo "===== the DATA of both objects is identical ====="
diff <(kubectl get cm app-config             -n "$NS" -o jsonpath='{.data}' | tr ',' '\n' | sort) \
     <(kubectl get cm app-config-imperative  -n "$NS" -o jsonpath='{.data}' | tr ',' '\n' | sort) \
  && echo "no differences in .data"
echo

echo "===== the METADATA is not ====="
echo "--- declarative object keeps a last-applied-configuration annotation:"
kubectl get cm app-config -n "$NS" -o jsonpath='{.metadata.annotations}' | head -c 200; echo
echo "--- imperative object has no such annotation:"
kubectl get cm app-config-imperative -n "$NS" -o jsonpath='{.metadata.annotations}'; echo "(empty)"
echo

echo "===== re-running apply is idempotent; re-running create is not ====="
kubectl apply -f configmap.yaml
kubectl create configmap app-config-imperative -n "$NS" --from-literal=DB_HOST=db-svc || true
echo

echo "===== clean up the imperative copy ====="
kubectl delete configmap app-config-imperative -n "$NS"
