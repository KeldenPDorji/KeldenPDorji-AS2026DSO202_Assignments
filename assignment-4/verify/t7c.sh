#!/bin/bash
source "$(dirname "$0")/lib.sh"; cap t7c
BAD=$(cat "$A4/outputs/bad-sha.txt"); git checkout -q -b revert/backend-1.2; git revert --no-edit "$BAD" >/dev/null; git push -q -u origin revert/backend-1.2
gh pr create --base main --head revert/backend-1.2 --title "Revert release 1.2: backend" --body "Recovery through Git" >/dev/null; gh pr merge revert/backend-1.2 --squash --delete-branch >/dev/null
git checkout -q main; git pull -q --ff-only origin main; git branch -qD revert/backend-1.2 2>/dev/null || true; H=$(git rev-parse HEAD); refresh tasktracker-dev
hdr "revert merged"; git log --oneline -2
echo "Argo CD finishes retrying the failed sync first, so this can take several minutes"
wait_rev tasktracker-dev "$H" 1200s; wait_op tasktracker-dev "$H" 1200s
hdr "dev after the revert"; appstate tasktracker-dev; kubectl get pods -n dso202-dev -l app.kubernetes.io/component=backend --no-headers | awk '{print $1,$2,$3}'
echo "api: $(kubectl exec -n dso202-dev deploy/tasktracker-frontend -- curl -s http://tasktracker-backend:8080/api/status)"
hdr "the bad commit is still in history"; git log --oneline -4 | cut -c1-70
