#!/bin/bash
# Helm: what a release is, and where it is recorded.
#
# Run from the helm/ directory, after installing tt-dev. This is the thing
# Kustomize has no equivalent of: kubectl knows about individual objects, but
# nothing in the cluster answers "which version of the application is running"
# or "what else was deployed alongside it".
set -eu
NS=dso202-a3-helm
REL=tt-dev

echo "RELEASES"
helm list -n "$NS"

echo
echo "OBJECTS HELM CREATED AND NOW OWNS"
helm get manifest "$REL" -n "$NS" | grep -E '^kind:' | sort | uniq -c | awk '{printf "  %s x %s\n", $1, $3}'

echo
echo "THE MARKERS HELM PUTS ON EVERY OBJECT IT CREATES"
kubectl get deploy -n "$NS" "$REL-task-tracker-backend" -o jsonpath='  label      app.kubernetes.io/managed-by = {.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}  annotation meta.helm.sh/release-name  = {.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}  annotation meta.helm.sh/release-ns    = {.metadata.annotations.meta\.helm\.sh/release-namespace}{"\n"}'
echo "  Helm refuses to adopt an object that already exists without these."

echo
echo "THE RELEASE RECORD IS AN ORDINARY SECRET IN THE NAMESPACE"
kubectl get secret -n "$NS" -l owner=helm --show-labels --no-headers | awk '{print "  " $1 "  " $NF}'

echo
echo "DECODED (gzip inside base64 inside base64)"
kubectl get secret "sh.helm.release.v1.$REL.v1" -n "$NS" -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip | jq -c '{name, namespace, version, status: .info.status, apply_method, chart: .chart.metadata.version, values: .config}' | fold -w 100 | sed 's/^/  /'

echo
echo "USER-SUPPLIED values are only what -f and --set provided. The MERGED set"
echo "adds the chart defaults, and is equally recoverable from this namespace:"
helm get values "$REL" -n "$NS" --all 2>/dev/null | grep -A2 '^credentials:' | sed 's/^/  /'
echo "  Helm does not keep secrets secret. A real password supplied to a release"
echo "  is readable by anyone who can read Secrets here."
