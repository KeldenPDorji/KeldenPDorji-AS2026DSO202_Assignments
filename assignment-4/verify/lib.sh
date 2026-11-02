# Shared helpers for the Assignment 4 evidence scripts. Run every script from
# the root of the dso202-gitops clone. Output is copied to assignment-4/outputs/
# so docs/evidence.md can be written from the exact text in Phase 2.
A4="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cap() { mkdir -p "$A4/outputs"; exec > >(tee "$A4/outputs/$1.txt") 2>&1; }
hdr() { printf '\n== %s\n' "$*"; }
refresh() { kubectl annotate application "$1" -n argocd argocd.argoproj.io/refresh=normal --overwrite >/dev/null; }
appstate() { kubectl get application "$1" -n argocd -o jsonpath='{.metadata.name}: {.status.sync.status} / {.status.health.status} @ {.status.sync.revision}{"\n"}' | sed -E 's/@ ([0-9a-f]{7})[0-9a-f]+/@ \1/'; }
apps() { for a in $(kubectl get applications -n argocd -o name | sed 's#.*/##'); do appstate "$a"; done; }
wait_rev() { kubectl wait --for=jsonpath="{.status.sync.revision}=$2" "application/$1" -n argocd --timeout="${3:-300s}" >/dev/null; }
wait_app() { kubectl wait --for=jsonpath='{.status.sync.status}=Synced' "application/$1" -n argocd --timeout="${2:-300s}" >/dev/null; kubectl wait --for=jsonpath='{.status.health.status}=Healthy' "application/$1" -n argocd --timeout="${2:-300s}" >/dev/null; }
wait_smoke() { kubectl wait --for=condition=Complete job/tasktracker-smoke-test -n "$1" --timeout=240s >/dev/null; }
active_rs() { kubectl get rs -n "$1" -l app.kubernetes.io/component="$2" --no-headers | awk '$2>0 {print $1}' | tr '\n' ' '; }
ship() { # ship <branch> <title>: PR the working-tree change, squash-merge it, sync main
  git checkout -q -b "$1"; git add -A; git commit -q -m "$2"; git push -q -u origin "$1" >/dev/null 2>&1
  gh pr create --base main --head "$1" --title "$2" --body "$2" >/dev/null
  gh pr merge "$1" --squash --delete-branch >/dev/null
  git checkout -q main; git pull -q --ff-only origin main >/dev/null 2>&1; git branch -qD "$1" 2>/dev/null || true; }
wait_op() { # wait_op <app> <revision> <timeout>: the sync of this revision finished
  kubectl wait --for=jsonpath="{.status.operationState.syncResult.revision}=$2" "application/$1" -n argocd --timeout="${3:-300s}" >/dev/null
  kubectl wait --for=jsonpath='{.status.operationState.phase}=Succeeded' "application/$1" -n argocd --timeout="${3:-300s}" >/dev/null
  wait_app "$1" "${3:-300s}"; }
rel() { kubectl exec -n "$1" "deploy/tasktracker-$2" -- printenv RELEASE 2>/dev/null || echo unset; }
