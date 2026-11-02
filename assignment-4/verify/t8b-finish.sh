#!/bin/bash
# t8b.sh timed out waiting for a sync the revert did not need. This keeps its
# saved output, timeout line included, and adds the state after the revert.
source "$(dirname "$0")/lib.sh"; SAVED=$(sed '/^== restored by git revert/,$d' "$A4/outputs/t8b.txt"); cap t8b
printf '%s\n' "$SAVED"
hdr "restored by git revert"; git log --oneline -1 | cut -c1-70; appstate tasktracker-dev
echo "drill-quota in cluster: $(kubectl get resourcequota drill-quota -n dso202-dev --no-headers 2>/dev/null | wc -l | tr -d ' ')"
echo "last sync operation: $(kubectl get application tasktracker-dev -n argocd -o json | jq -r '.status.operationState | "\(.phase) @ \(.syncResult.revision[0:7])"')"
echo "full refusal: $(kubectl get application tasktracker-dev -n argocd -o jsonpath='{.status.operationState.message}' | sed 's/.*tasks are not valid: //')"
echo "note: the timeout above is the script's own wait. The ResourceQuota was never"
echo "applied, so after the revert dev already matched Git and no new sync ran."
