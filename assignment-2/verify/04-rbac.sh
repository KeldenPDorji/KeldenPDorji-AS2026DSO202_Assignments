#!/bin/bash
# 2.3 - RBAC, verified empirically with kubectl auth can-i rather than by
# reading the manifests and hoping (2.3.6).
set -eu
NS=dso202-assignment-02
VIEWER=system:serviceaccount:$NS:app-viewer
AUDITOR=system:serviceaccount:$NS:namespace-auditor
DEPLOYER=system:serviceaccount:$NS:deployer

ask() { printf '  %-46s %s\n' "$1" "$(kubectl auth can-i $2 --as="$3" ${4:+-n $4} 2>/dev/null || true)"; }

echo "===== A. app-viewer: read-only inside this namespace ====="
ask "list pods"                       "list pods"                    "$VIEWER" "$NS"
ask "get pod logs"                    "get pods/log"                 "$VIEWER" "$NS"
ask "list statefulsets"               "list statefulsets.apps"       "$VIEWER" "$NS"
ask "delete pods"                     "delete pods"                  "$VIEWER" "$NS"
ask "create deployments"              "create deployments.apps"      "$VIEWER" "$NS"
echo "  -- secrets are in no rule at all, because reading one IS the credential:"
ask "get secrets"                     "get secrets"                  "$VIEWER" "$NS"

echo
echo "===== B. resourceNames narrows a rule to specific objects (2.3.5) ====="
ask "get configmap/app-config"        "get configmaps/app-config"    "$VIEWER" "$NS"
ask "get configmap/kube-root-ca.crt"  "get configmaps/kube-root-ca.crt" "$VIEWER" "$NS"
ask "list configmaps (any)"           "list configmaps"              "$VIEWER" "$NS"
echo "  Named object permitted, every other ConfigMap denied, listing denied."

echo
echo "===== C. scope comes from the BINDING type, not the ROLE type (2.3.9) ====="
echo "  namespace-auditor is bound to the built-in ClusterRole 'view'"
echo "  through a RoleBinding, so it is confined to one namespace:"
ask "list pods in $NS"                "list pods"                    "$AUDITOR" "$NS"
ask "list pods in kube-system"        "list pods"                    "$AUDITOR" "kube-system"
ask "list nodes (cluster-scoped)"     "list nodes"                   "$AUDITOR"
echo "  A ClusterRoleBinding would have granted all three. A RoleBinding does not."

echo
echo "===== D. update and patch are DIFFERENT verbs (2.3.8) ====="
kubectl apply -f rbac/deployer.yaml >/dev/null   # reset the Role to its declared state
ask "update deployments"              "update deployments.apps"      "$DEPLOYER" "$NS"
ask "patch deployments"               "patch deployments.apps"       "$DEPLOYER" "$NS"
echo
echo "  kubectl apply issues a PATCH, not an update, against an object that"
echo "  already exists. Here is that request, made as the deployer:"
kubectl patch deployment backend -n "$NS" --as="$DEPLOYER" --type=merge -p '{"metadata":{"annotations":{"deployed-by":"ci-pipeline"}}}' 2>&1 | head -3 || true

echo
echo "  Diagnose the actual rule rather than escalating to cluster-admin:"
kubectl describe role deployer-role -n "$NS" | sed -n '/PolicyRule/,$p' | head -6

echo
echo "  Fix: add exactly the one missing verb."
kubectl patch role deployer-role -n "$NS" --type=json -p='[{"op":"add","path":"/rules/0/verbs/-","value":"patch"}]'
ask "patch deployments (after fix)"   "patch deployments.apps"       "$DEPLOYER" "$NS"
kubectl patch deployment backend -n "$NS" --as="$DEPLOYER" --type=merge -p '{"metadata":{"annotations":{"deployed-by":"ci-pipeline"}}}' 2>&1 | head -2

echo
echo "  No ClusterRole, no ClusterRoleBinding, and no permission outside"
echo "  $NS was required to resolve it."
