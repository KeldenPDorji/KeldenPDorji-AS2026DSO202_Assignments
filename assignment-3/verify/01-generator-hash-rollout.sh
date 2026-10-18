#!/bin/bash
# Kustomize: content change -> hash change -> reference change -> Pod template
# change -> rollout.
#
# This is the chain that makes a generated ConfigMap safe to change. Editing a
# hand-written ConfigMap has no effect at all on the Pods that read it, because
# a Deployment rolls out only when its Pod template changes.
#
# The active ReplicaSet is reported rather than the Pod name: a ReplicaSet's
# name is derived from a hash of the Pod template, so a new ReplicaSet IS the
# proof that the template changed. Pod names are also racy to read while an old
# Pod is still terminating.
set -eu
NS=dso202-a3-dev
ENVFILE=base/config/app.env
cfgname() { kubectl kustomize overlays/dev | grep -oE 'app-config-[a-z0-9]+' | head -1; }
ref() { kubectl get deploy backend -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}'; }
rs() { kubectl get rs -n "$NS" -l tier=backend --no-headers | awk '$2>0 {print $1}'; }

echo "BEFORE"
echo "  rendered ConfigMap name : $(cfgname)"
echo "  live backend reference  : $(ref)"
echo "  active ReplicaSet       : $(rs)"
OLD=$(cfgname)

echo
echo "CHANGE  $ENVFILE : CORS_ORIGIN -> http://localhost:30080"
sed -i '' 's|^CORS_ORIGIN=.*|CORS_ORIGIN=http://localhost:30080|' "$ENVFILE"

echo
echo "RENDER (local only, nothing sent to the cluster)"
echo "  rendered ConfigMap name : $(cfgname)    <- changed, because the CONTENT changed"

echo
echo "APPLY"
kubectl apply -k overlays/dev 2>&1 | grep -E 'configmap|deployment'
kubectl rollout status deploy/backend -n "$NS" --timeout=300s | tail -1

echo
echo "AFTER"
echo "  live backend reference  : $(ref)"
echo "  active ReplicaSet       : $(rs)    <- new template, so new ReplicaSet"
echo "  previous ConfigMap      : $(kubectl get cm "$OLD" -n "$NS" --no-headers 2>/dev/null | awk '{print $1}' || echo gone) (orphaned; apply -k does not prune)"

echo
echo "RESTORE  (identical content must reproduce the identical hash)"
sed -i '' 's|^CORS_ORIGIN=.*|CORS_ORIGIN=*|' "$ENVFILE"
echo "  rendered ConfigMap name : $(cfgname)"
test "$(cfgname)" = "$OLD" && echo "  matches the original - the build is deterministic"
kubectl apply -k overlays/dev >/dev/null
kubectl rollout status deploy/backend -n "$NS" --timeout=300s | tail -1
echo "  cluster is back in step with the committed files"
