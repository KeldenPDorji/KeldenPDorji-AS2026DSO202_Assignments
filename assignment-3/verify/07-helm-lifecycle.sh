#!/bin/bash
# Helm: the upgrade values trap, and what a rollback really does.
#
# Run from the helm/ directory, with tt-dev installed at revision 1.
set -eu
NS=dso202-a3-helm
REL=tt-dev
vals() { helm get values "$REL" -n "$NS" -o json 2>/dev/null | jq -c .; }
rev()  { helm list -n "$NS" -o json | jq -r ".[] | select(.name==\"$REL\") | \"revision \(.revision), \(.status)\""; }
rs()   { kubectl get rs -n "$NS" -l app.kubernetes.io/component=backend --no-headers | awk '$2>0 {print $1}'; }

echo "REVISION 1 - the values supplied at install"
vals | fold -w 100 | sed 's/^/  /'
echo "  $(rev)   backend ReplicaSet: $(rs)"

echo
echo "UPGRADE passing only --set, with no -f  (the common CI mistake)"
helm upgrade "$REL" ./task-tracker -n "$NS" --set config.corsOrigin=https://example.com 2>&1 | head -1 | sed 's/^/  /'
echo "  When helm upgrade is given ANY value flag it restarts from the chart"
echo "  defaults and applies only this command's values. Everything in"
echo "  environments/dev.yaml was discarded; the chart's own required guard"
echo "  turned a silent configuration loss into a loud failure."
echo "  release untouched: $(rev)"

echo
echo "UPGRADE again with --reuse-values"
helm upgrade "$REL" ./task-tracker -n "$NS" --reuse-values --set config.corsOrigin=https://example.com --wait --timeout 10m 2>&1 | grep -E 'REVISION|STATUS' | sed 's/^/  /'
vals | fold -w 100 | sed 's/^/  /'
echo "  corsOrigin is merged INTO the previous values, not replacing them."
echo "  backend ReplicaSet: $(rs)  <- the checksum/config annotation changed,"
echo "  so the Pod template changed, so the Deployment rolled."

echo
echo "ROLLBACK to revision 1"
helm rollback "$REL" 1 -n "$NS" --wait --timeout 10m 2>&1 | sed 's/^/  /'
vals | fold -w 100 | sed 's/^/  /'

echo
echo "HISTORY"
helm history "$REL" -n "$NS" -o json | jq -r '.[] | "  \(.revision)  \(.status)\t\(.description)"'
echo "  A rollback does not delete revisions 1 and 2. It APPENDS revision 3"
echo "  holding a copy of revision 1, so the history records what happened."
