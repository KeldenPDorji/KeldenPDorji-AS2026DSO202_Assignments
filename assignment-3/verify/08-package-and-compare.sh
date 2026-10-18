#!/bin/bash
# Packaging, clean removal, and what each tool actually knows.
#
# Run from the helm/ directory, last. It uninstalls the release.
set -eu
NS=dso202-a3-helm
REL=tt-dev

echo "PACKAGING - a chart is a versioned, distributable artifact"
helm package ./task-tracker -d ../outputs 2>&1 | sed 's/^/  /'
printf '  archive: %s\n' "$(ls -lh ../outputs/task-tracker-*.tgz | awk '{print $NF, "(" $5 ")"}')"
helm show chart ../outputs/task-tracker-0.1.0.tgz | grep -E '^(name|version|appVersion|type):' | sed 's/^/  /'
echo "  The version is in the filename. Kustomize has no equivalent: a base is"
echo "  a directory in Git, versioned only by the commit that contains it."

echo
echo "WHAT EACH TOOL KNOWS ABOUT WHAT IT DEPLOYED"
printf '  %-24s %-28s %s\n' "" "Kustomize + kubectl" "Helm"
printf '  %-24s %-28s %s\n' "object inventory" "none in the cluster" "release record Secret"
printf '  %-24s %-28s %s\n' "application version" "none" "chart 0.1.0 / app 1.0"
printf '  %-24s %-28s %s\n' "change history" "git log only" "$(helm history "$REL" -n "$NS" -o json | jq 'length') revisions"
printf '  %-24s %-28s %s\n' "group rollback" "revert commit, re-apply" "helm rollback <revision>"
printf '  %-24s %-28s %s\n' "removal" "kubectl delete -k DIR" "helm uninstall <release>"
printf '  %-24s %-28s %s\n' "renamed object" "orphaned, not pruned" "tracked and removed"

echo
echo "UNINSTALL - one command removes every object in the release"
helm uninstall "$REL" -n "$NS" 2>&1 | sed 's/^/  /'
# helm uninstall returns as soon as the deletes are accepted. Wait for the
# objects to actually go, or the count below samples one mid-termination.
kubectl wait --for=delete pvc --all -n "$NS" --timeout=180s >/dev/null 2>&1 || true
kubectl wait --for=delete pod --all -n "$NS" --timeout=180s >/dev/null 2>&1 || true
printf '  objects left in %s   : %s (kube-root-ca.crt is injected by the cluster, not ours)\n' "$NS" "$(kubectl get deploy,svc,cm,secret,pvc -n "$NS" --no-headers 2>/dev/null | grep -v 'kube-root-ca' | wc -l | tr -d ' ')"
printf '  release records left        : %s\n' "$(kubectl get secret -n "$NS" -l owner=helm --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  namespace still present     : %s\n' "$(kubectl get ns "$NS" --no-headers | awk '{print $1, $2}')"
echo "  --create-namespace does not make the namespace part of the release,"
echo "  so the namespace is left behind deliberately."
