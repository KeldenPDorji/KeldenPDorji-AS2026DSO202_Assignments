#!/bin/bash
# Helm: no single check is sufficient.
#
# Run from the helm/ directory. A misspelled Kubernetes field - "replica"
# instead of "replicas" - is introduced into a THROWAWAY COPY of the chart, so
# the committed chart is never broken, and every check is then run against it.
#
# Templates produce text. They do not validate Kubernetes field names, which is
# why this defect survives the checks that never talk to an API server.
set -eu
BROKEN=/tmp/a3-broken-chart
rm -rf "$BROKEN"; mkdir -p "$BROKEN"
cp -R ./task-tracker "$BROKEN/"
sed -i '' 's/^  replicas: {{ .Values.backend.replicaCount }}/  replica: {{ .Values.backend.replicaCount }}/' "$BROKEN/task-tracker/templates/backend.yaml"
echo "injected defect: $(grep -m1 'replica' "$BROKEN/task-tracker/templates/backend.yaml" | sed 's/^ *//')"
echo

r() { printf '  %-44s %s\n' "$1" "$2"; }

if helm lint "$BROKEN/task-tracker" -f environments/dev.yaml >/dev/null 2>&1; then
  r "helm lint" "PASSED - it checks chart structure, not Kubernetes schemas"
else
  r "helm lint" "failed"
fi

if helm template tt "$BROKEN/task-tracker" -f environments/dev.yaml >/dev/null 2>&1; then
  r "helm template" "PASSED - valid YAML is not a valid Deployment"
else
  r "helm template" "failed"
fi

if helm install tt "$BROKEN/task-tracker" -f environments/dev.yaml -n dso202-a3-helm --create-namespace --dry-run=server >/dev/null 2>&1; then
  r "helm install --dry-run=server" "PASSED - renders against the cluster, but does not reject it"
else
  r "helm install --dry-run=server" "failed"
fi

OUT=$(helm template tt "$BROKEN/task-tracker" -f environments/dev.yaml --skip-tests 2>/dev/null | kubectl apply --dry-run=server -n default -f - 2>&1 || true)
if echo "$OUT" | grep -q 'unknown field'; then
  r "kubectl apply --dry-run=server" "REJECTED"
  printf '      the API server names the exact field: %s\n' "$(echo "$OUT" | grep -o 'unknown field "[^"]*"' | head -1)"
else
  r "kubectl apply --dry-run=server" "passed"
fi

echo
echo "Only the last check sends the object to the API server with strict field"
echo "validation, so only the last one can catch a field that does not exist."
echo "A real install would also reject it - but under server-side apply, after"
echo "earlier objects in the release have already been applied."
rm -rf "$BROKEN"
